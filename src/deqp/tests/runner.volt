// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Contains code and classes for running tests and reading back results.
 */
module deqp.tests.runner;

import watt = [
	watt.io.file,
	watt.io.streams,
	watt.text.string,
	];

import watt.path : sep = dirSeparator;

import deqp.io;
import deqp.sinks;
import deqp.driver;
import deqp.launcher;

import deqp.tests.test;
import deqp.tests.result;
import deqp.tests.parser;


/*!
 * A group of tests to be given to the testsuit.
 */
class Group
{
public:
	drv: Driver;
	suite: Suite;
	start, end: u32;

	fileCtsLog: string;
	fileConsole: string;
	fileTests: string;
	tests: Test[];


public:
	this(drv: Driver, suite: Suite, tests: Test[], offset: u32)
	{
		this.drv = drv;
		this.suite = suite;
		this.tests = tests;
		this.start = offset + 1;
		this.end = offset + cast(u32) tests.length;
		this.fileTests = new "${suite.tempDir}${sep}hasty_${start}.tests";
		this.fileCtsLog = new "${suite.tempDir}${sep}hasty_${start}.log";
		this.fileConsole = new "${suite.tempDir}${sep}hasty_${start}.console";

		drv.removeOnExit(fileTests);
		drv.removeOnExit(fileCtsLog);
		drv.removeOnExit(fileConsole);
	}

	fn run(launcher: Launcher)
	{
		args := [
			"--deqp-stdin-caselist",
			"--deqp-surface-type=window",
			new "--deqp-gl-config-name=${suite.config}",
			"--deqp-log-images=enable",
			"--deqp-watchdog=enable",
			"--deqp-visibility=hidden",
			new "--deqp-surface-width=${suite.surfaceWidth}",
			new "--deqp-surface-height=${suite.surfaceHeight}",
			new "--deqp-log-filename=${fileCtsLog}",
		];

		console := new watt.OutputFileStream(fileConsole);

		sss: StringsSink;
		foreach (test; tests) {
			sss.sink(test.name);
		}

		launcher.run(suite.command, args, sss.toArray(), console, done);
		console.close();
	}

	fn readResults()
	{
		parseResultsAndAssign(fileConsole, tests);
	}


private:
	fn done(retval: i32)
	{
		if (retval == 0) {
			// The test run completed okay.
			if (tests.length == 1) {
				info("\tGLES%s Done: %s", suite.suffix, tests[0].name);
			} else {
				info("\tGLES%s Done: %s .. %s", suite.suffix, start, end);
			}
		} else {
			// The test run didn't complete.
			if (tests.length == 1) {
				info("\tGLES%s Failed: %s, retval: %s", suite.suffix, tests[0].name, retval);
			} else {
				info("\tGLES%s Failed: %s .. %s, retval: %s", suite.suffix, start, end, retval);
			}

			// Preserve some files so the user can investigate.
			drv.preserveOnExit(fileConsole);
			drv.preserveOnExit(fileCtsLog);
		}
	}
}

struct GroupSink = mixin SinkStruct!Group;
