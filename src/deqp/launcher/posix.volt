// Copyright 2016-2018, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Launches tests.
 */
module deqp.launcher.posix;

version (Posix):

import core.exception;
import proc = watt.process;
import watt = [watt.io, watt.io.streams];
import posix = [core.c.posix.unistd, core.c.posix.fcntl];


class Launcher
{
private:
	mProcs: proc.Group;


public:
	this(numThreads: u32)
	{
		mProcs = new proc.Group(numThreads);
	}

	void run(cmd: string, args: string[], tests: string[], console: watt.OutputFileStream, done: dg(i32))
	{
		fds: i32[2];
		if (ret := posix.pipe(ref fds)) {
			throw new Exception("Failed to create pipe");
		}

		readFD := fds[0];
		writeFD := fds[1];

		// Close the input side for the child.
		posix.fcntl(writeFD, posix.F_SETFD, posix.FD_CLOEXEC);

		// Spawn the process.
		mProcs.run(cmd, args, readFD, console.fd, console.fd, null, done);

		// Close the output side.
		posix.close(readFD);

		// Write the tests to the file descriptor.
		foreach (test; tests) {
			posix.write(writeFD, cast(void*) test.ptr, test.length);
			posix.write(writeFD, cast(void*) "\n".ptr, 1);
		}

		// Close the input side.
		posix.close(writeFD);
	}

	fn waitAll()
	{
		mProcs.waitAll();
	}
}
