// Copyright 2018, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Launches tests.
 */
module deqp.launcher.windows;

version (Windows):

import watt = [watt.io, watt.io.streams];


class Launcher
{
public:
	this(numThreads: u32)
	{
	}

	void run(cmd: string, args: string[], tests: string[], console: watt.OutputFileStream, done: dg(i32))
	{
	}

	fn waitAll()
	{
	}
}
