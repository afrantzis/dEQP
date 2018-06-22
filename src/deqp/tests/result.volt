// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Contains code and classes for managing tests results.
 */
module deqp.tests.result;

import deqp.tests.test;


enum Result
{
	Incomplete,
	Fail,
	NotSupported,
	InternalError,
	QualityWarning,
	Pass,
}

fn isResultPassing(result: Result) bool
{
	final switch (result) with (Result) {
	case Incomplete:     return false;
	case Fail:           return false;
	case NotSupported:   return false;
	case InternalError:  return false;
	case QualityWarning: return true;
	case Pass:           return true;
	}
}

fn isResultFailing(result: Result) bool
{
	final switch (result) with (Result) {
	case Incomplete:     return true;
	case Fail:           return true;
	case NotSupported:   return false;
	case InternalError:  return true;
	case QualityWarning: return false;
	case Pass:           return false;
	}
}

fn isResultAndCompareRegression(result: Result, compare: Result) bool
{
	if (result.isResultFailing()) {
		return isResultPassing(compare);
	} else {
		return false;
	}
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

	suites: Suite[];


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

	fn getIncomplete() u32
	{
		return numIncomplete;
	}

	fn getTotal() u32
	{
		return numFail + numIncomplete + numInternalError +
		       numNotSupported + numPass + numQualityWarning +
		       numIncomplete + numInternalError;
	}

	fn count()
	{
		// Reset the old numbers.
		numFail = numIncomplete = numInternalError = numNotSupported =
			numPass = numQualityWarning = 0;

		foreach (suite; suites) {
			foreach (test; suite.tests) {
				final switch (test.result) with (Result) {
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
