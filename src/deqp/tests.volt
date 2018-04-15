// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Contains code and classes for parsing, managing and storing dEQP tests.
 */
module deqp.tests;

import watt = [
	watt.io.file,
	watt.text.sink,
	watt.text.string
	];

import deqp.io;
import deqp.sinks;
import deqp.driver;


fn parseTestFile(s: Settings)
{
	if (!watt.exists(s.testNamesFile) || !watt.isFile(s.testNamesFile)) {
		abort(new "Test names file '${s.testNamesFile}' does not exists!");
	}

	file := cast(string) watt.read(s.testNamesFile);
	lines := watt.splitLines(file);

	sss: StringsSink;

	info("Reading test names from '%s'", s.testNamesFile);

	foreach (line; lines) {
		if (watt.startsWith(line, "dEQP-GLES2")) {
			sss.sink(line);
		} else if (watt.startsWith(line, "#") || line.length == 0) {
			/* nop */
		} else {
			warn("Unknown tests '%s'", line);
		}
	}

	s.tests = sss.toArray();

	info("Done! Got %s tests", s.tests.length);
}
