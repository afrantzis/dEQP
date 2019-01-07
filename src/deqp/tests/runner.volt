// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Contains code and classes for running tests and reading back results.
 */
module deqp.tests.runner;

import watt = [
	watt.path,
	watt.io.file,
	watt.io.streams,
	watt.io.monotonic,
	watt.algorithm,
	watt.text.sink,
	watt.text.string,
	watt.text.format,
	watt.math.random,
	];

import watt.path : sep = dirSeparator;

import sig = core.c.signal;
import file = watt.io.file;
import proc = watt.process;

import deqp.io;
import deqp.sinks;
import deqp.driver;
import deqp.launcher;

import deqp.tests.test;
import deqp.tests.info;
import deqp.tests.result;
import deqp.tests.parser;


fn dispatch(drv: Driver, suites: Suite[])
{
	s := new Scheduler(drv, suites);

	foreach (suite; suites) {
		// Temporary directory.
		watt.mkdirP(suite.tempDir);

		// Set the correct working directory for running tests.
		file.chdir(suite.runDir);

		// Create a secheduling struct for the current suite.
		current: Current;
		current.setup(s, suite);


		if (drv.settings.randomize != 0) {
			current.runRandom();
		} else if (drv.settings.batchSize != 0) {
			current.runRest(drv.settings.batchSize);
		} else if (suite.suffix == "2") {
			current.runSingle("dEQP-GLES2.functional.flush_finish.wait");
			current.runStartsWith("dEQP-GLES2.functional.vertex_arrays.multiple_attributes");
			current.runRest();
		} else if (suite.suffix == "3") {
			// Run as separate tests.
			current.runStartsWith("dEQP-GLES3.functional.flush_finish", 1);
			current.runStartsWith("dEQP-GLES3.functional.shaders.builtin_functions.precision", 8);
			current.runStartsWith("dEQP-GLES3.functional.vertex_arrays.multiple_attributes", 8);
			current.runStartsWith("dEQP-GLES3.functional.vertex_arrays.single_attribute", 8);
			current.runStartsWith("dEQP-GLES3.functional.rasterization", 16);
			current.runRest();
		} else if (suite.suffix == "31") {
			current.runStartsWith("dEQP-GLES31.functional.shaders.builtin_functions.precision.refract", 1);
			current.runStartsWith("dEQP-GLES31.functional.shaders.builtin_functions.precision.faceforward", 1);
			current.runStartsWith("dEQP-GLES31.functional.shaders.builtin_functions.precision", 8);
			current.runStartsWith("dEQP-GLES31.functional.copy_image.compressed.viewclass", 8);
			current.runRest();
		} else {
			current.runRest();
		}
	}

	info("\tWaiting for test batchs to complete.");

	// Wait for all test groups to complete.
	drv.launcher.waitAll();
}

/*!
 * A group of tests to be given to the testsuit.
 */
class Group
{
public:
	drv: Driver;
	suite: Suite;
	start, end: u32;

	filePrefix: string;
	fileCtsLog: string;
	fileConsole: string;
	fileVtestLog: string;
	fileTests: string;
	tests: Test[];

	timeStart, timeStop: i64;

	//! Return value from runner.
	runnerRetVal: i32;
	runnerExited: bool;

	vtestPid: proc.Pid;
	vtestRetVal: i32;
	vtestExited: bool;

public:
	this(drv: Driver, suite: Suite, tests: Test[], offset: u32, filePrefix: string)
	{
		this.drv = drv;
		this.suite = suite;
		this.tests = tests;
		this.start = offset + 1;
		this.end = offset + cast(u32) tests.length;
		this.filePrefix = filePrefix;
		this.fileTests = new "${suite.tempDir}${sep}${filePrefix}_${start}.tests";
		this.fileCtsLog = new "${suite.tempDir}${sep}${filePrefix}_${start}.log";
		this.fileConsole = new "${suite.tempDir}${sep}${filePrefix}_${start}.console";
		this.fileVtestLog = new "${suite.tempDir}${sep}${filePrefix}_${start}.vtest-console";

		drv.removeOnExit(this.fileTests);
		drv.removeOnExit(this.fileCtsLog);
		drv.removeOnExit(this.fileConsole);
		drv.removeOnExit(this.fileVtestLog);
	}

	fn run(launcher: Launcher)
	{
		if (drv.settings.vtestCmd !is null) {
			return runWithVtest(launcher);
		}

		if (drv.settings.vtestCmd is null) {
			runTests(launcher);
		} else {
			assert(false, "vtest not supported on this platform!");
		}
	}


	fn writeTestsToFile()
	{
		f := new watt.OutputFileStream(fileTests);
		foreach (t; tests) {
			f.write(t.name);
			f.write("\n");
		}
		f.flush();
		f.close();
	}


private:
	fn makeArgs() string[]
	{
		return [
			"--deqp-stdin-caselist",
			"--deqp-surface-type=window",
			new "--deqp-gl-config-name=${suite.config}",
			"--deqp-log-images=enable",
			"--deqp-watchdog=enable",
			"--deqp-visibility=hidden",
			new "--deqp-surface-width=${suite.surfaceWidth}",
			new "--deqp-surface-height=${suite.surfaceHeight}",
			new "--deqp-log-filename=${fileCtsLog}",
		];
	}

	fn makeTestsString() string
	{
		ss: watt.StringSink;
		foreach (test; tests) {
			ss.sink(test.name);
			ss.sink("\n");
		}

		return ss.toString();
	}

	fn runTests(launcher: Launcher)
	{
		args := makeArgs();
		testsStr := makeTestsString();
		console := new watt.OutputFileStream(fileConsole);

		timeStart = watt.ticks();
		launcher.run(suite.command, args, testsStr, console, null, doneRunner);
		console.close();
	}

	version (Posix) fn runWithVtest(launcher: Launcher)
	{
		vtestCmd := drv.settings.vtestCmd;
		vtestConsole := new watt.OutputFileStream(fileVtestLog);
		vtestInput: string = null;
		vtestArgs: string[] = null;
		vtestEnv := proc.retrieveEnvironment();

		vtestPid = launcher.run(vtestCmd, vtestArgs, vtestInput, vtestConsole, vtestEnv, doneVtestCmd);
		vtestConsole.close();

		runnerEnv := proc.retrieveEnvironment();
		runnerEnv.set("LIBGL_ALWAYS_SOFTWARE", "true");
		runnerEnv.set("GALLIUM_DRIVER", "virpipe");
		runnerArgs := makeArgs();
		runnerInput := makeTestsString();
		runnerConsole := new watt.OutputFileStream(fileConsole);

		timeStart = watt.ticks();

		launcher.run(suite.command, runnerArgs, runnerInput, runnerConsole, runnerEnv, doneVtestRunner);
		runnerConsole.close();
	}

	version (Posix) fn doneVtestRunner(retval: i32)
	{
		info("doneVtestRunner");
		// Call normal handler function.
		doneRunner(this.runnerRetVal);

		// Kill the vtest process if it is still running.
		if (!vtestExited) {
			sig.kill(vtestPid._pid, sig.SIGTERM);
		}
	}

	version (Posix) fn doneVtestCmd(retval: i32)
	{
		info("doneVtestCmd");
		this.vtestExited = true;
		this.vtestRetVal = retval;

		if (retval != 0) {
			drv.preserveOnExit(fileVtestLog);
		}
	}

	fn doneRunner(retval: i32)
	{
		// Save the retval, for tracking BadTerminate status.
		this.runnerExited = true;
		this.runnerRetVal = retval;

		readResults();

		// Time keeping.
		timeStop = watt.ticks();
		ms := watt.convClockFreq(timeStop - timeStart, watt.ticksPerSecond, 1000);
		time := watt.format(" (%s.%03ss)", ms / 1000, ms % 1000);

		printResultFromGroup(suite, tests, retval, start, end, time);

		// If the test run didn't complete.
		if (retval != 0) {
			// Write out the tests to a file, for debugging.
			writeTestsToFile();

			// Preserve some files so the user can investigate.
			drv.preserveOnExit(fileConsole);
			drv.preserveOnExit(fileCtsLog);
			drv.preserveOnExit(fileTests);
		}
	}

	fn readResults()
	{
		parseResultsAndAssign(fileConsole, tests);

		// If the testsuit terminated cleanely nothing more to do.
		if (runnerRetVal == 0) {
			return;
		}

		// Loop over and set tests to BadTerminate(Pass).
		foreach (test; tests) {
			if (test.result != Result.Pass) {
				test.result = Result.BadTerminate;
			} else {
				test.result = Result.BadTerminatePass;
			}
		}
	}
}

struct GroupSink = mixin SinkStruct!Group;


private:

/*!
 * Schedules tests in a slightly more optimized way.
 */
final class Scheduler
{
public:
	drv: Driver;
	launcher: Launcher;

	numDispatched: size_t;
	numTests: size_t;

	gs: GroupSink;


public:
	enum MinBatchSize = Step4Size;

	enum Step1Left = 8192u;
	enum Step1Size = 64u;
	enum Step2Left = 4096u;
	enum Step2Size = 32u;
	enum Step3Left = 512u;
	enum Step3Size = 16u;
	enum Step4Size = 4u;


public:
	this(drv: Driver, suites: Suite[])
	{
		this.drv = drv;
		this.launcher = drv.launcher;

		foreach (suite; suites) {
			numTests += suite.tests.length;
		}
	}

	fn calcBatchSize() size_t
	{
		left := numTests - numDispatched;

		if (left > Step1Left) {
			return Step1Size;
		} else if (left > Step2Left) {
			return Step2Size;
		} else if (left > Step3Left) {
			return Step3Size;
		} else if (left > Step4Size) {
			return Step4Size;
		} else {
			return left;
		}
	}

	fn launch(suite: Suite, tests: Test[], offset: u32)
	{
		group := new Group(drv, suite, tests, offset, "batch");
		group.run(launcher);

		numDispatched += tests.length;
		gs.sink(group);
	}
}

/*!
 * Struct holding states for scheduling tests from a Suite.
 */
struct Current
{
public:
	store: size_t[string];
	tests: Test[];
	suite: Suite;
	offset: size_t;
	started: bool[];
	s: Scheduler;


public:
	fn setup(s: Scheduler, suite: Suite)
	{
		this.s = s;
		this.tests = suite.tests;
		this.suite = suite;
		this.offset = 0;
		this.started = new bool[](tests.length);

		foreach (i, test; suite.tests) {
			store[test.name] = i;
		}
	}

	fn runRandom()
	{
		tests = new Test[](tests);

		seed := s.drv.settings.randomize;

		r: watt.RandomGenerator;
		r.seed();

		info("\tRandomizing tests using seed %s", seed);

		i: i32 = cast(i32) tests.length - 1;

		for (; i >= 0; i--) {

			index := r.uniformI32(0, i);

			old := tests[index];
			tests[index] = tests[i];
			tests[i] = old;
		}

		runRest(s.drv.settings.batchSize);
	}

	/*!
	 * Start a single test of the extact name.
	 */
	fn runSingle(test: string)
	{
		ptr := test in store;
		if (ptr is null) {
			return;
		}

		i := *ptr;
		if (started[i]) {
			return;
		}

		// Inform the user.
		info("\tScheduling test '%s'.", test);

		// Launch the test, no need to give batch size since
		// it is only one test anyways.
		batch(i, i + 1);
	}

	/*!
	 * Schedule tests starting with the given string,
	 * in smaller batches then normal.
	 */
	fn runStartsWith(str: string, batchSize: size_t = 4u)
	{
		// Skip to first matching test.
		offset = 0;
		skipStartedOrNotMatching(str);

		// Early out if we didn't find any tests.
		if (offset >= tests.length) {
			return;
		}

		// Inform the user.
		info("\tScheduling tests starting with '%s'.", str);

		while (offset < tests.length) {
			start := offset;
			skipNotStartedAndMatching(str);
			end := offset;

			if (start == end) {
				break;
			}

			batch(start, end, batchSize);

			skipStartedOrNotMatching(str);
		}
	}

	/*!
	 * Schedule all remaining tests.
	 */
	fn runRest(batchSize: size_t = 0u)
	{
		// Skip to first matching test.
		offset = 0;
		skipStarted();

		// Early out if we didn't find any tests.
		if (offset >= tests.length) {
			return;
		}

		// Inform the user.
		info("\tScheduling all remaining GLES%s tests.", suite.suffix);

		while (offset < tests.length) {
			start := offset;
			skipNotStarted();
			end := offset;
			if (start == end) {
				break;
			}

			batch(start, end, batchSize);

			skipStarted();
		}
	}


private:
	fn skipStarted()
	{
		while (offset < started.length && started[offset]) {
			offset++;
		}
	}

	fn skipNotStarted()
	{
		while (offset < started.length && !started[offset]) {
			offset++;
		}
	}

	fn skipStartedOrNotMatching(str: string)
	{
		while (offset < started.length && (started[offset] ||
		       !watt.startsWith(tests[offset].name, str))) {
			offset++;
		}
	}

	fn skipNotStartedAndMatching(str: string)
	{
		while (offset < started.length && !started[offset] &&
		       watt.startsWith(tests[offset].name, str)) {
			offset++;
		}
	}

	fn batch(i1: size_t, i2: size_t, batchSize: size_t = 0)
	{
		offset := i1;
		tests := this.tests[0 .. i2];

		while (offset < tests.length) {
			left := tests.length - offset;
			size := batchSize != 0 ? batchSize : s.calcBatchSize();
			size = watt.min(left, size);

			t := markAndReturn(offset, offset + size);

			s.launch(suite, t, cast(u32) offset);

			offset += size;
		}
	}

	fn markAndReturn(i1: size_t, i2: size_t) Test[]
	{
		foreach (i; i1 .. i2) {
			started[i] = true;
		}

		return tests[i1 .. i2];
	}
}
