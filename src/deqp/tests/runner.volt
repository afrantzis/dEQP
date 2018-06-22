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


/*!
 * A group of tests to be given to the testsuit.
 */
class Group
{
public:
	drv: Driver;
	suite: Suite;
	offset: u32;
	numTests: u32;

	fileCtsLog: string;
	fileConsole: string;
	fileTests: string;

	//! Human readable starting number of test.
	final @property fn start() u32 { return offset + 1; }


public:
	this(drv: Driver, suite: Suite, offset: u32, numTests: u32)
	{
		this.drv = drv;
		this.suite = suite;
		this.offset = offset;
		this.numTests = numTests;
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
		foreach (test; suite.tests[offset .. offset + numTests]) {
			sss.sink(test.name);
		}

		launcher.run(suite.command, args, sss.toArray(), console, done);
		console.close();
	}


private:
	fn done(retval: i32)
	{
		if (numTests != 1 && retval == 0) {
			info("\tGLES%s Done: %s .. %s", suite.suffix, start, offset + numTests);
		} else if (numTests != 1) {
			info("\tGLES%s Failed: %s .. %s, retval: %s", suite.suffix, start, offset + numTests, retval);
			drv.preserveOnExit(fileConsole);
			drv.preserveOnExit(fileCtsLog);
		}

		parseResults();

		if (numTests == 1 && retval == 0) {
			info("\tGLES%s Done: %s", suite.suffix, suite.tests[offset].name);
		} else if (numTests == 1) {
			info("\tGLES%s Failed: %s, retval: %s", suite.suffix, suite.tests[offset].name, retval);
			drv.preserveOnExit(fileConsole);
			drv.preserveOnExit(fileCtsLog);
		}
	}

	fn writeTestsToFile()
	{
		f := new watt.OutputFileStream(fileTests);
		foreach (t; suite.tests[offset .. offset + numTests]) {
			f.write(t.name);
			f.write("\n");
		}
		f.flush();
		f.close();
	}

	enum HeaderName = "Test case '";
	enum HeaderIErr = "InternalError (";
	enum HeaderPass = "Pass (";
	enum HeaderFail = "Fail (";
	enum HeaderSupp = "NotSupported (";
	enum HeaderQual = "QualityWarning (";
	enum HeaderComp = "CompatibilityWarning (";

	fn parseResults()
	{
		console := cast(string) watt.read(fileConsole);

		map: u32[string];
		foreach (index, test; suite.tests[offset .. offset + numTests]) {
			map[test.name] = cast(u32)index + offset;
		}

		index: u32;
		string testCase;
		foreach (l; watt.splitLines(console)) {
			if (testCase.length == 0) {
				auto i = watt.indexOf(l, HeaderName);
				if (i < 0) {
					continue;
				} else {
					testCase = l[cast(size_t) i + HeaderName.length .. $ - 3];
					if (testCase in map is null) {
						warn("\t\tCould not find test '%s'?!", testCase);
						continue;
					}
					index = map[testCase];
				}
			} else {
				auto iPass = watt.indexOf(l, HeaderPass);
				auto iFail = watt.indexOf(l, HeaderFail);
				auto iSupp = watt.indexOf(l, HeaderSupp);
				auto iQual = watt.indexOf(l, HeaderQual);
				auto iIErr = watt.indexOf(l, HeaderIErr);
				auto iComp = watt.indexOf(l, HeaderComp);

				if (iPass >= 0) {
					//info("Pass %s", testCase);
					suite.tests[index].result = Result.Pass;
				} else if (iFail >= 0) {
					//auto res = l[iFail + startFail.length .. $ - 2].idup;
					suite.tests[index].result = Result.Fail;
				} else if (iSupp >= 0) {
					//info("!Sup %s", testCase);
					suite.tests[index].result = Result.NotSupported;
				} else if (iQual >= 0) {
					//info("Qual %s", testCase);
					suite.tests[index].result = Result.QualityWarning;
				} else if (iIErr >= 0) {
					//auto res = l[iIErr + startIErr.length .. $ - 2].idup;
					suite.tests[index].result = Result.InternalError;
				} else if (iComp >= 0) {
					//auto res = l[iComp + startComp.length .. $ - 2].idup;
					suite.tests[index].result = Result.CompatibilityWarning;
				} else {
					if (l.length > 0) {
						continue;
					}
				}
				index++;
				testCase = null;
			}
		}
	}
}
