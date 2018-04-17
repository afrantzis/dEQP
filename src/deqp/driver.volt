// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * This file the main control logic for the dEQP runnering program.
 */
module deqp.driver;

import watt = [
	watt.path,
	watt.io.file,
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


public:
	this()
	{
	}

	fn run(args: string[]) i32
	{
		settings = new Settings();
		settings.parseConfigFile();
		parseArgs(args);

		if (ret := checkArgs()) {
			return ret;
		}

		// All config is done read the tests file.
		settings.parseTestFile();

		// Looks up dependant paths and binaries.
		suite := new Suite(settings.ctsBuildDir, settings.tempDir);

		procs = new proc.Group(cast(u32) settings.numThreads);
		watt.mkdirP(suite.tempDir);
		watt.chdir(suite.runDir);

		tests := settings.tests;
		groups: Group[];
		count: u32;
		while (count < tests.length) {
			start := count + 1;
			num := watt.min(tests.length - count, cast(u32) settings.hastyBatchSize);
			subTests := new string[](num);
			foreach (ref test; subTests) {
				test = tests[count++];
			}

			group := new Group(suite, start, count, subTests);
			group.run(procs);
			groups ~= group;
		}

		procs.waitAll();

		numPass, numFail, numSkip, numQual: u32;
		foreach (testGroup; groups) {
			foreach (i, res; testGroup.results) {
				final switch (res) with (Result) {
				case Incomplete:
				case Failed:
				case InternalError:
					numFail++;
					break;
				case QualityWarning:
					numQual++;
					goto case;
				case Passed:
					numPass++;
					break;
				case NotSupported:
					numSkip++;
					break;
				}
			}
		}

		info("passed: %s, failed: %s, skipped: %s, quality warnings: %s, total: %s", numPass, numFail, numSkip, numQual, tests.length);
		return 0;
	}

	fn parseArgs(args: string[])
	{
		threads, hastyBatchSize: i32;
		testNamesFile, ctsBuildDir: string;

		watt.getopt(ref args, "threads", ref threads);
		watt.getopt(ref args, "hasty-batch-size", ref hastyBatchSize);
		watt.getopt(ref args, "cts-build-dir", ref ctsBuildDir);
		watt.getopt(ref args, "test-names-file", ref testNamesFile);

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

		version (Linux)if (ret) {
			info("dEQP will look for the config file here:");
			info("\t%s%s%s", watt.getConfigHome(), watt.dirSeparator, ConfigFile);
			foreach (dir; watt.getConfigDirs()) {
				info("\t%s%s%s", dir, watt.dirSeparator, ConfigFile);
			}
		}
		return ret;
	}
}
