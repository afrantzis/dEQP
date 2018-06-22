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
	info(" :: Printing failing tests.");
	foreach (suit; suites) {
		foreach (test; suit.tests) {
			final switch (test.result) with (Result) {
			case Pass, NotSupported, QualityWarning: break;
			case Incomplete, Fail, InternalError:
				info("%s", new "${test.name} ${test.result}");
				break;
			}
		}
	}
}
