// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Contains code and classes for parsing, managing and storing dEQP tests.
 */
module deqp.tests;

import watt = [
	watt.path,
	watt.io,
	watt.io.file,
	watt.io.streams,
	watt.text.string,
	];

import watt.path : sep = dirSeparator;
import proc = watt.process;

import deqp.io;
import deqp.sinks;
import deqp.driver;


enum Result
{
	Incomplete,
	Fail,
	NotSupported,
	InternalError,
	QualityWarning,
	Pass,
}

struct Results
{
public:
	numFail: u32;
	numIncomplete: u32;
	numInternalError: u32;
	numNotSupported: u32;
	numPass: u32;
	numQualityWarning: u32;

	groups: Group[];


public:
	fn getOk() u32
	{
		return numPass + numQualityWarning;
	}

	fn getSkip() u32
	{
		return numNotSupported;
	}

	fn getBad() u32
	{
		return numIncomplete + numFail + numInternalError;
	}

	fn getTotal() u32
	{
		return numFail + numIncomplete + numInternalError +
		       numNotSupported + numPass + numQualityWarning +
		       numIncomplete + numInternalError;
	}

	fn count()
	{
		foreach (testGroup; groups) {
			foreach (i, res; testGroup.results) {
				final switch (res) with (Result) {
				case Incomplete: numIncomplete++; break;
				case Fail: numFail++; break;
				case InternalError: numInternalError++; break;
				case QualityWarning: numQualityWarning++; break;
				case Pass: numPass++; break;
				case NotSupported: numNotSupported++; break;
				}
			}
		}
	}
}

class Suite
{
public:
	drv: Driver;
	command: string;
	runDir: string;
	tempDir: string;
	config: string = "rgba8888d24s8ms0";
	surfaceWidth: u32 = 256;
	surfaceHeight: u32 = 256;

	tests: string[];


public:
	this(drv: Driver, buildDir: string, tempBaseDir: string, suffix: string, tests: string[])
	{
		this.drv = drv;
		this.tests = tests;
		tempDir = new "${tempBaseDir}${sep}GLES${suffix}";
		command = new "${buildDir}${sep}modules${sep}gles${suffix}${sep}deqp-gles${suffix}";
		runDir = new "${buildDir}${sep}external${sep}openglcts${sep}modules";
	}
}

/*!
 * A group of tests to be given to the testsuit.
 */
class Group
{
public:
	drv: Driver;
	suite: Suite;
	start: u32;
	end: u32;
	tests: string[];
	results: Result[];

	fileCtsLog: string;
	fileConsole: string;
	fileTests: string;


public:
	this(drv: Driver, suite: Suite, start: u32, end: u32, tests: string[])
	{
		this.drv = drv;
		this.suite = suite;
		this.start = start;
		this.end = end;
		this.tests = tests;
		this.fileTests = new "${suite.tempDir}${sep}hasty_${start}.tests";
		this.fileCtsLog = new "${suite.tempDir}${sep}hasty_${start}.log";
		this.fileConsole = new "${suite.tempDir}${sep}hasty_${start}.console";
		this.results = new Result[](tests.length);

		drv.removeOnExit(fileTests);
		drv.removeOnExit(fileCtsLog);
		drv.removeOnExit(fileConsole);
	}

	fn run(procs: proc.Group)
	{
		writeTestsToFile();

		args := [
			new "--deqp-caselist-file=${fileTests}",
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
		procs.run(suite.command, args, watt.input, console, console, null, done);
	}


private:
	fn done(retval: i32)
	{
		if (retval == 0) {
			info("\tDone: %s .. %s", start, end);
		} else {
			info("\tFailed: %s .. %s, retval: %s", start, end, retval);
			drv.preserveOnExit(fileConsole);
			drv.preserveOnExit(fileCtsLog);
		}

		parseResults();
	}

	fn writeTestsToFile()
	{
		f := new watt.OutputFileStream(fileTests);
		foreach (t; tests) {
			f.write(t);
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

	fn parseResults()
	{
		console := cast(string) watt.read(fileConsole);

		map: u32[string];
		foreach (index, test; tests) {
			map[test] = cast(u32)index;
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

				if (iPass >= 0) {
					//info("Pass %s", testCase);
					results[index] = Result.Pass;
				} else if (iFail >= 0) {
					//auto res = l[iFail + startFail.length .. $ - 2].idup;
					results[index] = Result.Fail;
				} else if (iSupp >= 0) {
					//info("!Sup %s", testCase);
					results[index] = Result.NotSupported;
				} else if (iQual >= 0) {
					//info("Qual %s", testCase);
					results[index] = Result.QualityWarning;
				} else if (iIErr >= 0) {
					//auto res = l[iIErr + startIErr.length .. $ - 2].idup;
					results[index] = Result.InternalError;
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

/*!
 * Parse the given tests file.
 */
fn parseTestFile(s: Settings)
{
	if (!watt.exists(s.testNamesFile) || !watt.isFile(s.testNamesFile)) {
		abort(new "Test names file '${s.testNamesFile}' does not exists!");
	}

	info(" :: Gathering test names.");
	info("\tReading file ´%s'.", s.testNamesFile);

	file := cast(string) watt.read(s.testNamesFile);
	lines := watt.splitLines(file);

	g2: StringsSink;
	g3: StringsSink;
	g31: StringsSink;

	info("\tOrganizing tests.");
	foreach (line; lines) {
		if (watt.startsWith(line, "dEQP-GLES2")) {
			g2.sink(line);
		} else if (watt.startsWith(line, "dEQP-GLES3")) {
			g3.sink(line);
		} else if (watt.startsWith(line, "dEQP-GLES31")) {
			g31.sink(line);
		} else if (watt.startsWith(line, "#") || line.length == 0) {
			/* nop */
		} else {
			warn("Unknown tests '%s'", line);
		}
	}

	s.testsGLES2 = g2.toArray();
	s.testsGLES3 = g3.toArray();
	s.testsGLES31 = g31.toArray();

	info("\tGot %s tests.", s.testsGLES2.length + s.testsGLES3.length);
}
