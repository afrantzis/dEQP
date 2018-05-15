// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * This file the main control logic for the dEQP runnering program.
 */
module deqp.driver;

import watt = [
	watt.path,
	watt.io.streams,
	watt.algorithm,
	watt.xdg.basedir,
	watt.text.getopt,
	];

import proc = watt.process;
import file = watt.io.file;

import deqp.io;
import deqp.tests;
import deqp.driver;
import deqp.config;


/*!
 * Settings for the dEQP runner program are grouped here.
 */
class Settings
{
public:
	resultsFile: string;

	testNamesFile: string;
	ctsBuildDir: string;

	hasty: bool = true;
	hastyBatchSize: u32;

	threads: u32;

	tempDir: string = "/tmp/dEQP";

	testsGLES2: string[];
	testsGLES3: string[];
	testsGLES31: string[];
}

/*!
 * This does not represent a graphics but code that houses
 * logic for driving the dEQP process from start to finish.
 */
class Driver
{
public:
	settings: Settings;
	procs: proc.Group;
	results: Results;
	temporaryFiles: bool[string];


public:
	fn run(args: string[]) i32
	{
		settings = new Settings();
		parseConfigFile(settings);
		parseArgs(args);

		if (ret := checkArgs()) {
			return ret;
		}

		// Tell the user what is going on.
		printConfig(settings);

		// All config is done read the tests file.
		settings.parseTestFile();

		// Create worker pool.
		procs = new proc.Group(cast(u32) settings.threads);


		// Run all of the tests.
		info(" :: Running tests in groups of %s.", settings.hastyBatchSize);

		// Organize the tests
		if (settings.testsGLES2.length > 0) {
			tests := settings.testsGLES2;
			results.suites ~= new Suite(this, settings.ctsBuildDir, settings.tempDir, "2", tests);
		}
		if (settings.testsGLES3.length > 0) {
			tests := settings.testsGLES3;
			results.suites ~= new Suite(this, settings.ctsBuildDir, settings.tempDir, "3", tests);
		}
		if (settings.testsGLES31.length > 0) {
			tests := settings.testsGLES31;
			results.suites ~= new Suite(this, settings.ctsBuildDir, settings.tempDir, "31", tests);
		}


		// Save the working directory as we change it for each suite.
		originalWorkingDirectory := file.getcwd();

		// The main body of work.
		runTests();

		// Also checks if we should rerun the tests.
		rerunTests();

		// Set the old working directory.
		file.chdir(originalWorkingDirectory);

		info(" :: All test completed.");
		info("\tok: %s, bad: %s, skip: %s, total: %s", results.getOk(), results.getBad(), results.getSkip(), results.getTotal());

		// Write out the results
		writeResults();

		// Tidy after us.
		removeTemporaryFiles();

		info(" :: Exiting!");
		return 0;
	}

	fn parseArgs(args: string[])
	{
		threads, hastyBatchSize: i32;
		testNamesFile, ctsBuildDir, resultsFile: string;

		watt.getopt(ref args, "threads", ref threads);
		watt.getopt(ref args, "hasty-batch-size", ref hastyBatchSize);
		watt.getopt(ref args, "cts-build-dir", ref ctsBuildDir);
		watt.getopt(ref args, "test-names-file", ref testNamesFile);
		watt.getopt(ref args, "results-file", ref resultsFile);

		if (threads > 0) {
			settings.threads = cast(u32) threads;
		}
		if (hastyBatchSize > 0) {
			settings.hastyBatchSize = cast(u32) hastyBatchSize;
		}
		if (ctsBuildDir !is null) {
			settings.ctsBuildDir = ctsBuildDir;
		}
		if (testNamesFile !is null) {
			settings.testNamesFile = testNamesFile;
		}
		if (resultsFile !is null) {
			settings.resultsFile = resultsFile;
		}
	}

	fn checkArgs() i32
	{
		ret := 0;

		if (settings.threads == 0) {
			info("Number of threads not supplied, use:");
			info("\tArgument: --threads X");
			info("\tConfig: threads=X");

			ret = 1;
		}

		if (settings.hastyBatchSize == 0) {
			info("Hasty batch size not supplied, use:");
			info("\tArg:    --hasty-batch-size X");
			info("\tConfig: hastyBatchSize=X");

			ret = 1;
		}

		if (settings.ctsBuildDir is null) {
			info("CTS build dir not supplied, use:");
			info("\tArg:    --cts-build-dir X");
			info("\tConfig: ctsBuildDir=\"X\"");

			ret = 1;
		}

		if (settings.testNamesFile is null) {
			info("Test names file not supplied, use:");
			info("\tArg:    --test-names-file X");
			info("\tConfig: testNamesFile=\"X\"");

			ret = 1;
		}

		if (settings.resultsFile is null) {
			info("Result file not supplied, use:");
			info("\tArg:    --results-file X");
			info("\tConfig: resultsFile=\"X\"");

			ret = 1;
		}

		version (Linux)if (ret) {
			info("dEQP will look for the config file here:");
			info("\t%s%s%s", watt.getConfigHome(), watt.dirSeparator, ConfigFile);
			foreach (dir; watt.getConfigDirs()) {
				info("\t%s%s%s", dir, watt.dirSeparator, ConfigFile);
			}
		}
		return ret;
	}

	fn runTests()
	{
		// Loop over the testsuites
		foreach (suite; results.suites) {
			count: u32;
			tests := suite.tests;

			// Temporary directory.
			watt.mkdirP(suite.tempDir);

			// Set the correct working directory for running tests.
			file.chdir(suite.runDir);

			while (count < tests.length) {
				offset := count;
				num := cast(u32) watt.min(tests.length - count, settings.hastyBatchSize);

				group := new Group(this, suite, offset, num);
				group.run(procs);
				count += num;
			}
		}

		// Wait for all test groups to complete.
		procs.waitAll();

		// Count the results.
		results.count();
	}

	//! Fuzzyish logic for test rerunning.
	fn getRerunMask() u32
	{
		total := results.getTotal();
		bad := results.getBad();
		inc := results.getIncomplete();
		mask := 0x0_u32;
		val := true;

		// Early out to avoid printing info messages.
		if (bad == 0 || settings.hastyBatchSize == 1) {
			return 0;
		}

		info(" :: Rerunning failed test(s).");

		if ((total / 4) < bad) {
			mask |= 1u << Result.Fail;
			mask |= 1u << Result.InternalError;
		}

		if ((total / 4) < inc) {
			mask |= 1u << Result.Incomplete;
		}

		return mask;
	}

	fn rerunTests()
	{
		total := results.getTotal();
		bad := results.getBad();
		inc := results.getIncomplete();
		mask := 0x0_u32;
		val := true;

		// Early out to avoid printing info messages.
		if (bad == 0 || settings.hastyBatchSize == 1) {
			return;
		}

		info(" :: Rerunning failed test(s).");

		if ((total / 8) > (bad - inc)) {
			mask |= 1u << Result.Fail;
			mask |= 1u << Result.InternalError;
		} else {
			info("\tTo many failing tests %s", bad);
		}

		if ((total / 8) > inc) {
			mask |= 1u << Result.Incomplete;
		} else {
			info("\tTo many incomplete tests %s", inc);
		}

		if (mask == 0) {
			info("\tNot rerunning any tests as there are to many.");
			return;
		}

		// Flip bits
		mask = ~mask;

		foreach (suite; results.suites) {
			// Temporary directory.
			watt.mkdirP(suite.tempDir);

			// Set the correct working directory for running tests.
			file.chdir(suite.runDir);

			foreach (offset, res; suite.results) {
				if (mask & (1u << cast(u32) res)) {
					continue;
				}

				group := new Group(this, suite, cast(u32) offset, 1);
				group.run(procs);
			}
		}

		// Wait for all test groups to complete.
		procs.waitAll();

		// Recount the results
		results.count();
	}

	fn writeResults()
	{
		info(" :: Writing results to '%s'", settings.resultsFile);

		o := new watt.OutputFileStream(settings.resultsFile);
		o.writefln("# Fail %s", results.numFail);
		o.writefln("# InternalError %s", results.numInternalError);
		o.writefln("# Incomplete %s", results.numIncomplete);
		o.writefln("# NotSupported %s", results.numNotSupported);
		o.writefln("# Pass %s", results.numPass);
		o.writefln("# QualityWarning %s", results.numQualityWarning);
		foreach (suite; results.suites) {
			foreach (i, res; suite.results) {
				o.write(new "${suite.tests[i]} ${res}\n");
			}
		}
		o.flush();
		o.close();
		o = null;
		info("\tDone");
	}

	/*!
	 * Remove temporary files.
	 */
	fn removeTemporaryFiles()
	{
		info(" :: Cleaning up.");
		count: u32;
		foreach (k, v; temporaryFiles) {
			if (!v) {
				info("\tSaved '%s'", k);
			} else if (file.isFile(k)) {
				count++;
				file.remove(k);
			}
		}
		info("\tRemoved %s file(s).", count);
	}

	/*!
	 * Adds the file to the lists of files to be removed after close.
	 */
	fn removeOnExit(file: string) string
	{
		temporaryFiles[file] = true;
		return file;
	}

	/*!
	 * Don't remove the file on exit.
	 */
	fn preserveOnExit(file: string) string
	{
		temporaryFiles[file] = false;
		return file;
	}
}
