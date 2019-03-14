// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Contains code and classes for parsing dEQP tests.
 */
module deqp.tests.parser;

import watt = [
	watt.io.file,
	watt.text.string,
	];

import deqp.io;
import deqp.sinks;
import deqp.driver;

import deqp.tests.test;
import deqp.tests.result;


/*!
 * Parse the given tests file.
 */
fn parseTestFile(s: Settings)
{
	abortOnMissingTestsFile(s.testNamesFiles);
	lines: string[];

	info(" :: Gathering test names.");
	foreach (testNamesFile; s.testNamesFiles) {
		info("\tReading file %s.", testNamesFile);
		file := cast(string) watt.read(testNamesFile);
		lines ~= watt.splitLines(file);
	}

	gl3: StringsSink;
	gl31: StringsSink;
	gl32: StringsSink;
	gles2: StringsSink;
	gles3: StringsSink;
	gles31: StringsSink;

	info("\tOrganizing tests.");
	foreach (line; lines) {
		if (watt.startsWith(line, "dEQP-GLES2")) {
			gles2.sink(line);
		} else if (watt.startsWith(line, "dEQP-GLES31")) {
			gles31.sink(line);
		} else if (watt.startsWith(line, "dEQP-GLES3")) {
			gles3.sink(line);
		} else if (watt.startsWith(line, "KHR-GL30")) {
			gl3.sink(line);
		} else if (watt.startsWith(line, "KHR-GL31")) {
			gl31.sink(line);
		} else if (watt.startsWith(line, "KHR-GL31")) {
			gl32.sink(line);
		} else if (watt.startsWith(line, "#") || line.length == 0) {
			/* nop */
		} else {
			warn("Unknown tests '%s'", line);
		}
	}

	s.testsGL3 = gl3.toArray();
	s.testsGL31 = gl31.toArray();
	s.testsGL32 = gl32.toArray();
	s.testsGLES2 = gles2.toArray();
	s.testsGLES3 = gles3.toArray();
	s.testsGLES31 = gles31.toArray();

	info("\tGot %s tests.", s.testsGL3.length +
	                        s.testsGL31.length +
	                        s.testsGL32.length +
	                        s.testsGLES2.length +
	                        s.testsGLES3.length +
	                        s.testsGLES31.length);
}

fn parseAndCheckRegressions(suites: Suite[], filenames: string[]) i32
{
	abortOnMissingRegressionFile(filenames);

	info(" :: Checking for regressions.");

	// Build a searchable database.
	database: Test[string];
	foreach (suite; suites) {
		foreach (test; suite.tests) {
			database[test.name] = test;
		}
	}

	regressed, improvement, quality, any: bool;
	foreach (filename; filenames) {
		// Load the file and split into lines.
		info("\tReading file %s.", filename);
		file := cast(string) watt.read(filename);
		lines := watt.splitLines(file);

		// Skip any json header.
		count: size_t;
		foreach (line; lines) {
			if (watt.startsWith(line, "dEQP-GLES")) {
				break;
			}
			count++;
		}

		// Loop over all lines not including the JSON header.
		foreach (line; lines[count .. $]) {

			if (watt.startsWith(line, "KHR-GL30") ||
			    watt.startsWith(line, "KHR-GL31") ||
			    watt.startsWith(line, "KHR-GL32") ||
			    watt.startsWith(line, "dEQP-GLES2") ||
			    watt.startsWith(line, "dEQP-GLES31") ||
			    watt.startsWith(line, "dEQP-GLES3")) {
				/* nop */
			} else if (watt.startsWith(line, "#") || line.length == 0) {
				continue;
			} else {
				warn("Unknown tests '%s'", line);
				continue;
			}

			name, resultText: string;
			splitNameAndResult(line, out name, out resultText);
			t := name in database;
			if (t is null) {
				continue;
			}
			test := *t;

			test.compare = parseResult(resultText);

			// Update change tracking.
			improvement = improvement || test.hasImproved();
			regressed = regressed || test.hasRegressed();
			quality = quality || test.hasQualityChange();
			any = any || test.hasAnyChange();
		}
	}

	ret := 0;
	if (regressed) {
		info("\tRegression(s) found!");
		ret = 1;
	}

	if (improvement) {
		info("\tImprovement(s) found!");
		ret = 1;
	}

	if (quality) {
		info("\tQuality change(s) found.");
	}

	if (!improvement && !regressed && !quality) {
		if (any) {
			info("\tChange(s) found.");
			ret = 1;
		} else {
			info("\tNo change(s) found.");
		}
	}

	return ret;
}

fn parseResultsAndAssign(fileConsole: string, tests: Test[])
{
	console := cast(string) watt.read(fileConsole);

	map: u32[string];
	foreach (index, test; tests/*suite.tests[offset .. offset + numTests]*/) {
		map[test.name] = cast(u32)index;
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
				tests[index].result = Result.Pass;
			} else if (iFail >= 0) {
				//auto res = l[iFail + startFail.length .. $ - 2].idup;
				tests[index].result = Result.Fail;
			} else if (iSupp >= 0) {
				//info("!Sup %s", testCase);
				tests[index].result = Result.NotSupported;
			} else if (iQual >= 0) {
				//info("Qual %s", testCase);
				tests[index].result = Result.QualityWarning;
			} else if (iIErr >= 0) {
				//auto res = l[iIErr + startIErr.length .. $ - 2].idup;
				tests[index].result = Result.InternalError;
			} else if (iComp >= 0) {
				//auto res = l[iComp + startComp.length .. $ - 2].idup;
				tests[index].result = Result.CompatibilityWarning;
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


private:

enum HeaderName = "Test case '";
enum HeaderIErr = "InternalError (";
enum HeaderPass = "Pass (";
enum HeaderFail = "Fail (";
enum HeaderSupp = "NotSupported (";
enum HeaderQual = "QualityWarning (";
enum HeaderComp = "CompatibilityWarning (";

fn splitNameAndResult(text: string, out name: string, out result: string) string
{
	foreach(i, dchar c; text) {
		if (watt.isWhite(c)) {
			name = text[0 .. i];
			text = text[i .. $];
			break;
		}
	}

	foreach (i, dchar c; text) {
		if (!watt.isWhite(c)) {
			text = text[i .. $];
			break;
		}
	}

	foreach (i, dchar c; text) {
		if (watt.isWhite(c)) {
			text = text[0 .. i];
			break;
		}
	}

	result = text[0 .. $];
	return text;
}

fn parseResult(text: string) Result
{
	switch (text) {
	case "Incomplete":           return Result.Incomplete;
	case "Fail":                 return Result.Fail;
	case "NotSupported":         return Result.NotSupported;
	case "InternalError":        return Result.InternalError;
	case "BadTerminate":         return Result.BadTerminate;
	case "BadTerminatePass":     return Result.BadTerminatePass;
	case "QualityWarning":       return Result.QualityWarning;
	case "CompatibilityWarning": return Result.CompatibilityWarning;
	case "Pass":                 return Result.Pass;
	default:                     return Result.Incomplete;
	}
}

fn abortOnMissingTestsFile(filenames: string[])
{
	foreach (filename; filenames) {
		if (!watt.exists(filename) || !watt.isFile(filename)) {
			abort(new "Test names file '${filename}' does not exists!");
		}
	}
}

fn abortOnMissingRegressionFile(filenames: string[])
{

	foreach (filename; filenames) {
		if (!watt.exists(filename) || !watt.isFile(filename)) {
			abort(new "Regression file '${filename}' does not exists!");
		}
	}
}
