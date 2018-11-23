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
				test.printRegression();
			} else if (test.hasQualityChange()) {
				test.printAnyChange();
			} else if (test.hasAnyChange()) {
				test.printAnyChange();
			} else if (test.hasFailed()) {
				test.printFail();
			}
		}
	}
}


private:


fn printRegression(test: Test)
{
	info("%s %s \u001b[41;1mREGRESSED\u001b[0m from (%s)", test.name, test.result.format(), test.compare.format());
}

fn printAnyChange(test: Test)
{
	info("%s %s was (%s)", test.name, test.result.format(), test.compare.format());
}

fn printFail(test: Test)
{
	info("%s %s", test.name, test.result.format());
}

fn format(res: Result) string
{
	final switch (res) with (Result) {
	case Incomplete:           return "\u001b[31mIncomplete\u001b[0m";
	case Fail:                 return "\u001b[31mFail\u001b[0m";
	case NotSupported:         return "\u001b[34mNotSupported\u001b[0m";
	case InternalError:        return "\u001b[31mInternalError\u001b[0m";
	case BadTerminate:         return "\u001b[31mBadTerminate\u001b[0m";
	case BadTerminatePass:     return "\u001b[31mBadTerminatePass\u001b[0m";
	case QualityWarning:       return "\u001b[33mQualityWarning\u001b[0m";
	case CompatibilityWarning: return "\u001b[33mCompatibilityWarning\u001b[0m";
	case Pass:                 return "\u001b[32mPass\u001b[0m";
	}
}
