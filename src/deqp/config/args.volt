// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Contains the code for parsing args.
 */
module deqp.config.args;

import watt = [
	watt.text.getopt,
	];

import deqp.io;
import deqp.driver;
import deqp.config.info;


fn parseArgs(settings: Settings, args: string[])
{
	printFailing: bool;
	threads, hastyBatchSize: i32;
	testNamesFile, ctsBuildDir, resultsFile, tempDir, regressionFile: string;

	watt.getopt(ref args, "threads", ref threads);
	watt.getopt(ref args, "hasty-batch-size", ref hastyBatchSize);
	watt.getopt(ref args, "cts-build-dir", ref ctsBuildDir);
	watt.getopt(ref args, "test-names-file", ref testNamesFile);
	watt.getopt(ref args, "results-file", ref resultsFile);
	watt.getopt(ref args, "temp-dir", ref tempDir);
	watt.getopt(ref args, "print-failing", ref printFailing);
	watt.getopt(ref args, "check|regression-file", ref regressionFile);

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
	if (tempDir !is null) {
		settings.tempDir = tempDir;
	}
	if (printFailing) {
		settings.printFailing = printFailing;
	}
	if (regressionFile) {
		settings.regressionFile = regressionFile;
	}

	if (args.length > 1) {
		info("Unknown argument '%s'", args[1]);
		printAllArgsAndConfig();
		abort(" :: Exiting!");
	}
}
