// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Contains code and classes for running tests and reading back results.
 */
module deqp.tests.runner;

import watt = [
	watt.path,
	watt.io.file,
	watt.io.streams,
	watt.algorithm,
	watt.text.sink,
	watt.text.string,
	];

import watt.path : sep = dirSeparator;

import file = watt.io.file;

import deqp.io;
import deqp.sinks;
import deqp.driver;
import deqp.launcher;

import deqp.tests.test;
import deqp.tests.result;
import deqp.tests.parser;


fn dispatch(drv: Driver, suites: Suite[])
{
	s: Scheduler;
	foreach (suite; suites) {
		s.numTests += suite.tests.length;

		foreach (test; suite.tests) {
			s.store[test.name] = test;
		}
	}


	// Store temporary groups.
	gs: GroupSink;

	foreach (suite; suites) {
		numDispatched: size_t;
		offset: size_t;
		tests := suite.tests;

		// Temporary directory.
		watt.mkdirP(suite.tempDir);

		// Set the correct working directory for running tests.
		file.chdir(suite.runDir);

		{
			group := new Group(drv, suite, tests[1 .. 3], cast(u32) 1);
			tests[1].started = true;
			tests[2].started = true;
			group.run(drv.launcher);
			numDispatched += 2;
			gs.sink(group);
		}

		while (offset < tests.length) {
			while (tests[offset].started) {
				offset++;
			}

			if (offset >= tests.length) {
				break;
			}

			size := calcBatchSize(s.numTests, numDispatched, 20);
			num := watt.min(tests.length - offset, size);

			// Don't run tests multiple times.
			foreach (i, test; tests[offset .. offset + num]) {
				if (test.started) {
					num = i;
					break;
				}

				test.started = true;
			}

			group := new Group(drv, suite, tests[offset .. offset + num], cast(u32) offset);
			group.run(drv.launcher);
			offset += num;
			numDispatched += num;
			gs.sink(group);
		}
	}

	// Wait for all test groups to complete.
	drv.launcher.waitAll();

	// As the function says.
	drv.readResults(gs.toArray());
}

fn launch(ref gs: GroupSink)
{
	
}

import io = watt.io;

fn calcBatchSize(numTests: size_t, numDispatched: size_t, numThreads: size_t) size_t
{
	left := numTests - numDispatched;
	if (left <= 4) {
		return left;
	}

	size: size_t = 512;
	while (((size * numThreads * 4) > left) && size > 4) {
		size = size >> 1;
	}

	io.writefln("aa %s %s %s", numTests, numDispatched, size);
	io.output.flush();
	return size;
}

/*!
 * Schedules tests in a slightly more optimized way.
 */
struct Scheduler
{
	store: Test[string];
	numTests: size_t;
}

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

		ss: watt.StringSink;
		foreach (test; tests) {
			ss.sink(test.name);
			ss.sink("\n");
		}

		launcher.run(suite.command, args, ss.toString(), console, done);
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
