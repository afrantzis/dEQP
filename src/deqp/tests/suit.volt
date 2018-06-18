// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Contains class for organising tests.
 */
module deqp.tests.suit;

import deqp.driver;
import deqp.tests.result;

import watt.path : sep = dirSeparator;


class Suite
{
public:
	drv: Driver;
	suffix: string;
	command: string;
	runDir: string;
	tempDir: string;
	config: string = "rgba8888d24s8ms0";
	surfaceWidth: u32 = 256;
	surfaceHeight: u32 = 256;

	tests: string[];
	results: Result[];


public:
	this(drv: Driver, buildDir: string, tempBaseDir: string, suffix: string, tests: string[])
	{
		this.drv = drv;
		this.tests = tests;
		this.suffix = suffix;
		this.results = new Result[](tests.length);
		tempDir = new "${tempBaseDir}${sep}GLES${suffix}";
		command = new "${buildDir}${sep}modules${sep}gles${suffix}${sep}deqp-gles${suffix}";
		runDir = new "${buildDir}${sep}external${sep}openglcts${sep}modules";
	}
}
