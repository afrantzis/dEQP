// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * This file the main control logic for the dEQP runnering program.
 */
module deqp.driver;

import watt = [
	watt.algorithm
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

	hasty: bool;
	hastySize: u32;

	numThreads: u32;


public:
	this()
	{
		numThreads = 4;
		hasty = true;
		hastySize = 100;
	}
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


private:


public:
	this()
	{
	}

	fn run(args: string[]) i32
	{
		settings = new Settings();
		settings.parseConfigFile();
		settings.parseTestFile();

		procs = new proc.Group(settings.numThreads);

		tests := settings.tests;
		count: u32;
		while (count < tests.length) {
			num := watt.min(tests.length - count, settings.hastySize);
			subTests := new string[](num);
			foreach (ref test; subTests) {
				test = tests[count++];
			}
			procs.run("/bin/echo", subTests, done);
		}

		procs.waitAll();
		return 0;
	}

	fn done(retval: int)
	{
		info("Done %s", retval);
	}
}
