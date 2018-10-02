// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Contains code and classes for managing tests results.
 */
module deqp.tests.info;

import deqp.io;

import deqp.tests.test;
import deqp.tests.result;


fn printResultsToStdout(suites: Suite[])
{
	info(" :: Printing changes and failing tests.");
	foreach (suit; suites) {
		foreach (test; suit.tests) {
			if (test.hasRegressed()) {
				info("%s", new "${test.name} ${test.result} (REGRESSION! ${test.compare})");
			} else if (test.hasFailed()) {
				info("%s", new "${test.name} ${test.result}");
			} else if (test.hasQualityChange()) {
				info("%s", new "${test.name} ${test.result} (was ${test.compare})");
			} else if (test.hasAnyChange()) {
				info("%s", new "${test.name} ${test.result} (was ${test.compare})");
			}
		}
	}
}
