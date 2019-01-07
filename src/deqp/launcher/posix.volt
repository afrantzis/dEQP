// Copyright 2016-2018, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Posix implementation of program launcher.
 */
module deqp.launcher.posix;

version (Posix):

import core.exception;
import proc = watt.process;
import watt = [watt.io, watt.io.streams];
import posix = [core.c.posix.unistd, core.c.posix.fcntl];


/*!
 * Used to launch programs and managed launched programs.
 */
class Launcher
{
private:
	mProcs: proc.Group;


public:
	this(numThreads: u32)
	{
		mProcs = new proc.Group(numThreads);
	}

	/*!
	 * Launch a program @p cmd with @p args and pipe @p input to it's
	 * standard input. Should the maximum number of threads been reached
	 * this function will block until one has completed.
	 *
	 * @param[in] cmd The program to launch.
	 * @param[in] args Arguments to the program.
	 * @param[in] input Pipe the contents to stdin. The program to launch.
	 * @param[in] console Used as stdout and stderr.
	 * @param[in] done Delegate to be called on program termination.
	 */
	fn run(cmd: string, args: string[], input: string, console: watt.OutputFileStream, env: proc.Environment, done: dg(i32)) proc.Pid
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
		pid := mProcs.run(cmd, args, readFD, console.fd, console.fd, env, done);

		// Close the output side.
		posix.close(readFD);

		// Write the tests to the file descriptor.
		posix.write(writeFD, cast(void*) input.ptr, input.length);

		// Close the input side.
		posix.close(writeFD);

		return pid;
	}

	/*!
	 * Wait for all launched processes to complete.
	 */
	fn waitAll()
	{
		mProcs.waitAll();
	}
}
