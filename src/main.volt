// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
module main;

import watt = [
	watt.algorithm,
	];

import deqp.io;
import deqp.tests;
import deqp.driver;
import deqp.config;


fn main(args: string[]) i32
{
	d := new Driver();
	return d.run(args);
}
