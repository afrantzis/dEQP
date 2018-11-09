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
	launcher: Launcher;
	results: Results;
	temporaryFiles: bool[string];


public:
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

		// The main body of work.
		runTests();

		// Also checks if we should rerun the tests.
		rerunTests();

		// Set the old working directory.
		file.chdir(originalWorkingDirectory);

		info(" :: All test completed.");
		info("\tok: %s, warn: %s, bad: %s, skip: %s, total: %s", results.getPass(), results.getWarn(), results.getBad(), results.getSkip(), results.getTotal());

		// Write out the results
		writeResults();

		// Tidy after us.
		removeTemporaryFiles();

		// Regrssion checking or print failing tests?
		ret: i32;
		if (settings.regressionFiles.length > 0) {
			ret = parseAndCheckRegressions(results.suites, settings.regressionFiles);
		}

		if (settings.printFailing || settings.regressionFiles !is null) {
			printResultsToStdout(results.suites);
		}

		info(" :: Exiting!");
		return ret;
	}

	fn runTests()
	{
		// Run all of the tests.
		info(" :: Running tests.", settings.batchSize);

		// Loop over the testsuites
		dispatch(this, results.suites);

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

		// As the function says.
		readResults(gs.toArray());

		// Recount the results
		results.count();
	}

	fn readResults(groups: scope Group[])
	{
		// As the info string says.
		info(" :: Reading results");
		then := watt.ticks();

		foreach (group; groups) {
			group.readResults();
		}

		now := watt.ticks();
		ms := watt.convClockFreq(now - then, watt.ticksPerSecond, 1000);
		info("\tDone in %s.%03sms", ms / 1000, ms % 1000);
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
	 * Don't remove the file on exit.
	 */
	fn preserveOnExit(file: string) string
	{
		temporaryFiles[file] = false;
		return file;
	}
}
