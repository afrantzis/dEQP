// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * This file the main control logic for the dEQP runnering program.
 */
module deqp.driver;

import watt = [
	watt.path,
	watt.io.streams,
	watt.io.monotonic,
	watt.algorithm,
	watt.xdg.basedir,
	watt.text.getopt,
	];

import file = watt.io.file;

import deqp.io;
import deqp.tests;
import deqp.driver;
import deqp.config;
import deqp.launcher;


/*!
 * Settings for the dEQP runner program are grouped here.
 */
class Settings
{
public:
	resultsFile: string;

	testNamesFiles: string[];
	ctsBuildDir: string;

	batchSize: u32;

	printFailing: bool = false;

	randomize: u32;

	threads: u32;

	tempDir: string = "/tmp/dEQP";

	regressionFiles: string[];

	testsGL3: string[];
	testsGL31: string[];
	testsGL32: string[];
	testsGL33: string[];
	testsGL4: string[];
	testsGL41: string[];
	testsGL42: string[];
	testsGL43: string[];
	testsGL44: string[];
	testsGL45: string[];
	testsGL46: string[];
	testsGLES2: string[];
	testsGLES3: string[];
	testsGLES31: string[];
}

/*!
 * This does not represent a graphics driver but code that houses logic for
 * driving the dEQP process from start to finish.
 */
class Driver
{
public:
	settings: Settings;
	launcher: Launcher;
	results: Results;
	temporaryFiles: bool[string];


public:
	/*!
	 * Main function, called from @ref main.main.
	 */
	fn run(args: string[]) i32
	{
		settings = new Settings();
		parseConfigFile(settings);
		parseArgs(settings, args);

		if (ret := checkArgs(settings)) {
			return ret;
		}

		// Tell the user what is going on.
		printConfig(settings);

		// All config is done read the tests file.
		settings.parseTestFile();

		// Save the working directory as we change it for each suite.
		originalWorkingDirectory := file.getcwd();

		// Create worker pool.
		launcher = new Launcher(cast(u32) settings.threads);

		// Organize the tests
		if (settings.testsGL3.length > 0) {
			tests := settings.testsGL3;
			results.suites ~= new KhrSuite(this, settings.ctsBuildDir, settings.tempDir, "3", tests);
		}
		if (settings.testsGL31.length > 0) {
			tests := settings.testsGL31;
			results.suites ~= new KhrSuite(this, settings.ctsBuildDir, settings.tempDir, "31", tests);
		}
		if (settings.testsGL32.length > 0) {
			tests := settings.testsGL32;
			results.suites ~= new KhrSuite(this, settings.ctsBuildDir, settings.tempDir, "32", tests);
		}
		if (settings.testsGL33.length > 0) {
			tests := settings.testsGL33;
			results.suites ~= new KhrSuite(this, settings.ctsBuildDir, settings.tempDir, "33", tests);
		}
		if (settings.testsGL4.length > 0) {
			tests := settings.testsGL4;
			results.suites ~= new KhrSuite(this, settings.ctsBuildDir, settings.tempDir, "4", tests);
		}
		if (settings.testsGL41.length > 0) {
			tests := settings.testsGL41;
			results.suites ~= new KhrSuite(this, settings.ctsBuildDir, settings.tempDir, "41", tests);
		}
		if (settings.testsGL42.length > 0) {
			tests := settings.testsGL42;
			results.suites ~= new KhrSuite(this, settings.ctsBuildDir, settings.tempDir, "42", tests);
		}
		if (settings.testsGL43.length > 0) {
			tests := settings.testsGL43;
			results.suites ~= new KhrSuite(this, settings.ctsBuildDir, settings.tempDir, "43", tests);
		}
		if (settings.testsGL44.length > 0) {
			tests := settings.testsGL44;
			results.suites ~= new KhrSuite(this, settings.ctsBuildDir, settings.tempDir, "44", tests);
		}
		if (settings.testsGL45.length > 0) {
			tests := settings.testsGL45;
			results.suites ~= new KhrSuite(this, settings.ctsBuildDir, settings.tempDir, "45", tests);
		}
		if (settings.testsGL46.length > 0) {
			tests := settings.testsGL46;
			results.suites ~= new KhrSuite(this, settings.ctsBuildDir, settings.tempDir, "46", tests);
		}
		if (settings.testsGLES2.length > 0) {
			tests := settings.testsGLES2;
			results.suites ~= new CtsSuite(this, settings.ctsBuildDir, settings.tempDir, "2", tests);
		}
		if (settings.testsGLES3.length > 0) {
			tests := settings.testsGLES3;
			results.suites ~= new CtsSuite(this, settings.ctsBuildDir, settings.tempDir, "3", tests);
		}
		if (settings.testsGLES31.length > 0) {
			tests := settings.testsGLES31;
			results.suites ~= new CtsSuite(this, settings.ctsBuildDir, settings.tempDir, "31", tests);
		}

		// The main body of work.
		runTests();

		// Also checks if we should rerun the tests.
		rerunTests();

		// Set the old working directory.
		file.chdir(originalWorkingDirectory);

		info(" :: All test completed.");
		info("\tok: %s, warn: %s, bad: %s, skip: %s, total: %s", results.getPass(), results.getWarn(), results.getBad(), results.getSkip(), results.getTotal());

		// First pass at getting a return code.
		ret: i32;
		if (results.getBad() > 0) {
			ret = 1;
		}

		// Write out the results
		writeResults();

		// Tidy after us.
		removeTemporaryFiles();

		// Regrssion checking, will overwrite old return code.
		if (settings.regressionFiles.length > 0) {
			ret = parseAndCheckRegressions(results.suites, settings.regressionFiles);
		}

		// Print failing tests?
		if (settings.printFailing || settings.regressionFiles.length > 0) {
			printResultsToStdout(results.suites);
		}

		info(" :: Exiting!");
		return ret;
	}

	/*!
	 * Run all of the gathered tests.
	 */
	fn runTests()
	{
		// Run all of the tests.
		info(" :: Running tests.", settings.batchSize);

		// Loop over the testsuites
		dispatch(this, results.suites);

		// Count the results.
		results.count();
	}

	/*!
	 * Fuzzyish logic for test rerunning.
	 */
	fn getRerunMask() u32
	{
		total := results.getTotal();
		bad := results.getBad();
		inc := results.getIncomplete();
		mask := 0x0_u32;
		val := true;

		// Early out to avoid printing info messages.
		if (bad == 0 || settings.batchSize == 1) {
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

	/*!
	 * Rerun tests that have failed in a batch.
	 */
	fn rerunTests()
	{
		total := results.getTotal();
		bad := results.getBad();
		inc := results.getIncomplete();
		mask := 0x0_u32;
		val := true;

		// Early out to avoid printing info messages.
		if (bad == 0 || settings.batchSize == 1) {
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
			mask |= 1u << Result.BadTerminate;
			mask |= 1u << Result.BadTerminatePass;
		} else {
			info("\tTo many incomplete tests %s", inc);
		}

		if (mask == 0) {
			info("\tNot rerunning any tests as there are to many.");
			return;
		}

		// Flip bits
		mask = ~mask;

		// Store temporary groups.
		gs: GroupSink;

		// Finally dispatch all failing tests.
		foreach (suite; results.suites) {
			// Temporary directory.
			watt.mkdirP(suite.tempDir);

			// Set the correct working directory for running tests.
			file.chdir(suite.runDir);

			foreach (offset, test; suite.tests) {
				if (mask & (1u << cast(u32) test.result)) {
					continue;
				}

				// Need to reset the test result.
				test.result = Result.Incomplete;

				// Then launch the test.
				group := new Group(this, suite, suite.tests[offset .. offset + 1], cast(u32) offset, "rerun");
				group.run(launcher);
				gs.sink(group);
			}
		}

		// Wait for all test groups to complete.
		launcher.waitAll();

		// Recount the results
		results.count();
	}

	/*!
	 * Write out results into a format that is easy to parse.
	 */
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
		o.writefln("# CompatibilityWarning %s", results.numCompatibilityWarning);
		foreach (suite; results.suites) {
			foreach (test; suite.tests) {
				o.write(new "${test.name} ${test.result}\n");
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
	 * Don't remove the file on exit, this function allows
	 * you to regret adding a file to the remove list with
	 * @ref deqp.driver.Driver.removeOnExit.
	 */
	fn preserveOnExit(file: string) string
	{
		temporaryFiles[file] = false;
		return file;
	}
}
