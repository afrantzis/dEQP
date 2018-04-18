// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * This file the main control logic for the dEQP runnering program.
 */
module deqp.driver;

import watt = [
	watt.path,
	watt.io.file,
	watt.io.streams,
	watt.algorithm,
	watt.xdg.basedir,
	watt.text.getopt,
	];

import proc = watt.process;

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
	tests: string[];

	hasty: bool = true;
	hastyBatchSize: u32;

	numThreads: u32;

	tempDir: string = "/tmp/dEQP";
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


public:
	fn run(args: string[]) i32
	{
		settings = new Settings();
		parseConfigFile(settings);
		parseArgs(args);

		if (ret := checkArgs()) {
			return ret;
		}

		// All config is done read the tests file.
		settings.parseTestFile();

		// Looks up dependant paths and binaries.
		suite := new Suite(settings.ctsBuildDir, settings.tempDir);

		// Create worker pool.
		procs = new proc.Group(cast(u32) settings.numThreads);

		// Temporary directory.
		watt.mkdirP(suite.tempDir);

		// Set the correct working directory for running tests.
		originalWorkingDirectory := watt.getcwd();
		watt.chdir(suite.runDir);

		// Run all of the tests.
		info(" :: Running tests in groups of %s.", settings.hastyBatchSize);
		tests := settings.tests;
		groups: Group[];
		count: u32;
		while (count < tests.length) {
			start := count + 1;
			num := watt.min(tests.length - count, settings.hastyBatchSize);
			subTests := new string[](num);
			foreach (ref test; subTests) {
				test = tests[count++];
			}

			group := new Group(suite, start, count, subTests);
			group.run(procs);
			results.groups ~= group;
		}

		// Wait for all test groups to complete.
		procs.waitAll();

		// Set the old working directory.
		watt.chdir(originalWorkingDirectory);

		results.count();

		info(" :: All test completed.");
		info("\tok: %s, bad: %s, skip: %s, total: %s", results.getOk(), results.getBad(), results.getSkip(), tests.length);

		// Write out the results
		writeResults();

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
			settings.numThreads = cast(u32) threads;
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

		if (settings.numThreads == 0) {
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

	fn writeResults()
	{
		info(" :: Writing results to '%s'", settings.resultsFile);

		o := new watt.OutputFileStream(settings.resultsFile);
		o.writefln("# Fail", results.numFail);
		o.writefln("# InternalError", results.numInternalError);
		o.writefln("# Incomplete", results.numIncomplete);
		o.writefln("# NotSupported", results.numNotSupported);
		o.writefln("# Pass", results.numPass);
		o.writefln("# QualityWarning", results.numQualityWarning);
		foreach (testGroup; results.groups) {
			foreach (i, res; testGroup.results) {
				o.write(new "${testGroup.tests[i]} ${res}\n");
			}
		}
		o.flush();
		o.close();
		o = null;
		info("\tDone");
	}
}
