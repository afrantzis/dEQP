// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Contains the code for info printing of the config, config file and for args.
 */
module deqp.config.info;

import watt = [
	watt.path,
	watt.xdg.basedir,
	watt.text.getopt,
	];

import deqp.io;
import deqp.driver;
import deqp.config.parser;


fn printConfig(s: Settings)
{
	info(" :: Config");
	info("\ttestNamesFile  = '%s'"	, s.testNamesFile);
	info("\tctsBuildDir    = '%s'", s.ctsBuildDir);
	info("\thastyBatchSize = %s", s.hastyBatchSize);
	info("\tthreads        = %s", s.threads);
	info("\tresultsFile    = '%s'", s.resultsFile);
	info("\ttempDir        = '%s'", s.tempDir);
}

fn printAllArgsAndConfig()
{
	printThreads();
	printHastyBatchSize();
	printCtsBuildDir();
	printTestNamesFile();
	printResultsFile();
	printTempDir();
	printConfigFile();
}

fn checkArgs(settings: Settings) i32
{
	ret := 0;

	if (settings.threads == 0) {
		printThreads(" not supplied, use:");
		ret = 1;
	}

	if (settings.hastyBatchSize == 0) {
		printHastyBatchSize(" not supplied, use:");
		ret = 1;
	}

	if (settings.ctsBuildDir is null) {
		printCtsBuildDir(" not supplied, use:");
		ret = 1;
	}

	if (settings.testNamesFile is null) {
		printTestNamesFile(" not supplied, use:");
		ret = 1;
	}

	if (settings.resultsFile is null) {
		printResultsFile(" not supplied, use:");
		ret = 1;
	}

	if (settings.tempDir is null) {
		printResultsFile(" not supplied, use:");
		ret = 1;
	}

	if (ret) {
		printConfigFile();
	}

	return ret;
}


private:

fn printThreads(suffix: string = ":")
{
	info("Number of threads%s", suffix);
	info("\tArgument: --threads X");
	info("\tConfig: threads=X");
}

fn printHastyBatchSize(suffix: string = ":")
{
	info("Hasty batch size%s", suffix);
	info("\tArg:    --hasty-batch-size X");
	info("\tConfig: hastyBatchSize=X");
}

fn printCtsBuildDir(suffix: string = ":")
{
	info("CTS build dir%s", suffix);
	info("\tArg:    --cts-build-dir X");
	info("\tConfig: ctsBuildDir=\"X\"");
}

fn printTestNamesFile(suffix: string = ":")
{
	info("Test names file%s", suffix);
	info("\tArg:    --test-names-file X");
	info("\tConfig: testNamesFile=\"X\"");
}

fn printResultsFile(suffix: string = ":")
{
	info("Result file%s", suffix);
	info("\tArg:    --results-file X");
	info("\tConfig: resultsFile=\"X\"");
}

fn printTempDir(suffix: string = ":")
{
	info("Temp dir%s", suffix);
	info("\tArg:    --temp-dir X");
	info("\tConfig: tempDir=\"X\"");
}

fn printConfigFile()
{
	version (Linux) {
		info("dEQP will look for the config file here:");
		info("\t%s%s%s", watt.getConfigHome(), watt.dirSeparator, ConfigFile);
		foreach (dir; watt.getConfigDirs()) {
			info("\t%s%s%s", dir, watt.dirSeparator, ConfigFile);
		}
	}
}
