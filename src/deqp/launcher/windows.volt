// Copyright 2018, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Stub code to at least compile on windows.
 */
module deqp.launcher.windows;

version (Windows):

import watt = [watt.io, watt.io.streams];
import proc = watt.process;


class Launcher
{
public:
	this(numThreads: u32)
	{
	}

	fn run(cmd: string, args: string[], input: string, console: watt.OutputFileStream, env: proc.Enviroment, done: dg(i32)) Pid
	{
		return null;
	}

	fn waitAll()
	{
	}
}
