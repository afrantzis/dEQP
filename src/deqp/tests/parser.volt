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

import deqp.tests.result;


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
		} else if (watt.startsWith(line, "dEQP-GLES31")) {
			g31.sink(line);
		} else if (watt.startsWith(line, "dEQP-GLES3")) {
			g3.sink(line);
		} else if (watt.startsWith(line, "#") || line.length == 0) {
			/* nop */
		} else {
			warn("Unknown tests '%s'", line);
		}
	}

	s.testsGLES2 = g2.toArray();
	s.testsGLES3 = g3.toArray();
	s.testsGLES31 = g31.toArray();

	info("\tGot %s tests.", s.testsGLES2.length + s.testsGLES3.length + s.testsGLES31.length);
}
