// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Contains code and classes for managing tests results.
 */
module deqp.tests.result;

import deqp.tests.suit;


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
			foreach (i, res; suite.results) {
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
