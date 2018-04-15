// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Houses small io related functions and classes.
 */
module deqp.io;

import core.varargs : va_list, va_start, va_end;
import core.c.stdlib : cExit = exit;

import watt = [watt.io, watt.io.file, watt.text.sink];


fn warn(fmt: watt.SinkArg, ...)
{
	vl: va_list;
	va_start(vl);
	watt.error.vwritefln(fmt, ref _typeids, ref vl);
	watt.error.flush();
	va_end(vl);
}

fn info(fmt: watt.SinkArg, ...)
{
	vl: va_list;
	va_start(vl);
	watt.output.vwritefln(fmt, ref _typeids, ref vl);
	watt.output.flush();
	va_end(vl);
}

fn abort(fmt: watt.SinkArg, ...)
{
	vl: va_list;
	va_start(vl);
	watt.error.vwritefln(fmt, ref _typeids, ref vl);
	watt.error.flush();
	va_end(vl);
	cExit(-1);
}
