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
	buildDir: string;
	tests: string[];

	hasty: bool = true;
	hastySize: u32 = 10;

	numThreads: u32 = 4;

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
		settings.parseTestFile();

		// Looks up dependant paths and binaries.
		suite := new Suite(settings.buildDir, settings.tempDir);

		procs = new proc.Group(settings.numThreads);
		watt.mkdirP(suite.tempDir);
		watt.chdir(suite.runDir);

		tests := settings.tests;
		groups: Group[];
		count: u32;
		while (count < tests.length) {
			start := count + 1;
			num := watt.min(tests.length - count, settings.hastySize);
			subTests := new string[](num);
			foreach (ref test; subTests) {
				test = tests[count++];
			}

			group := new Group(suite, start, count, subTests);
			group.run(procs);
			groups ~= group;
		}

		procs.waitAll();

		numPass, numFail, numSkip: u32;
		foreach (testGroup; groups) {
			foreach (i, res; testGroup.results) {
				final switch (res) with (Result) {
				case Incomplete:
				case Failed:
				case InternalError:
					numFail++;
					break;
				case QualityWarning:
				case Passed:
					numPass++;
					break;
				case NotSupported:
					numSkip++;
					break;
				}
			}
		}

		info("passed: %s, failed: %s, skipped: %s, total: %s", numPass, numFail, numSkip, tests.length);
		return 0;
	}
}
