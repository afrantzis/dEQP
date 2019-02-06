// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Contains class for tests organising them into test suits.
 */
module deqp.tests.test;

import deqp.sinks;
import deqp.driver;
import deqp.tests.result;

import watt.path : sep = dirSeparator;


struct Test
{
private:
	static struct TestData
	{
		enum Size = typeid(TestData).size;

		result: Result;
		compare: Result;
		size: u32;
		started: bool;
	}


private:
	ptr: TestData*;


public:
	@property fn name() string { return ptr is null ? null : (cast(immutable(char)*) &ptr[1])[0 .. ptr.size]; }
	@property fn result() Result { return ptr is null ? cast(Result) Result.default : ptr.result; }
	@property fn compare() Result { return ptr is null ? cast(Result) Result.default : ptr.compare; }
	@property fn started() bool { return ptr is null ? false : ptr.started; }
	@property fn result(r: Result) Result { if (ptr !is null) ptr.result = r; return r; }
	@property fn compare(r: Result) Result { if (ptr !is null) ptr.compare = r; return r; }
	@property fn started(r: bool) bool { if (ptr !is null) ptr.started = r; return r; }

	fn hasImproved() bool
	{
		return isResultAndCompareImprovement(result, compare);
	}

	fn hasRegressed() bool
	{
		return isResultAndCompareRegression(result, compare);
	}

	fn hasQualityChange() bool
	{
		return isResultAndCompareQualityChange(result, compare);
	}

	fn hasAnyChange() bool
	{
		return isResultAndCompareAnyChange(result, compare);
	}

	fn hasPassed() bool
	{
		return isResultPassing(result);
	}

	fn hasFailed() bool
	{
		return isResultFailing(result);
	}

	fn set(name: string)
	{
		arr := new char[](TestData.Size + name.length + 1);
		arr[TestData.Size .. TestData.Size + name.length] = name;

		this.ptr = cast(TestData*) arr.ptr;
		this.ptr.size = cast(u32) name.length;
	}
}

class Suite
{
public:
	drv: Driver;
	api: string;
	suffix: string;
	command: string;
	runDir: string;
	tempDir: string;
	config: string = "rgba8888d24s8ms0";
	surfaceWidth: u32 = 256;
	surfaceHeight: u32 = 256;

	tests: Test[];

	this(drv: Driver, buildDir: string, tempBaseDir: string, suffix: string, tests: string[])
	{
		this.drv = drv;
		this.suffix = suffix;
		runDir = new "${buildDir}${sep}external${sep}openglcts${sep}modules";

		this.tests = new Test[](tests.length);
		foreach (i, ref test; this.tests) {
			test.set(tests[i]);
		}
	}
}

class CtsSuite : Suite
{
	this(drv: Driver, buildDir: string, tempBaseDir: string, suffix: string, tests: string[])
	{
		super(drv, buildDir, tempBaseDir, suffix, tests);
		api = "GLES";
		tempDir = new "${tempBaseDir}${sep}GLES${suffix}";
		command = new "${buildDir}${sep}modules${sep}gles${suffix}${sep}deqp-gles${suffix}";
	}
}

class KhrSuite : Suite
{
	this(drv: Driver, buildDir: string, tempBaseDir: string, suffix: string, tests: string[])
	{
		super(drv, buildDir, tempBaseDir, suffix, tests);
		api = "GL";
		tempDir = new "${tempBaseDir}${sep}GL${suffix}";
		command = new "${buildDir}${sep}external${sep}openglcts${sep}modules${sep}glcts";
	}
}
