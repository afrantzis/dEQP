// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
module main;

import deqp.driver;


fn main(args: string[]) i32
{
	d := new Driver();
	return d.run(args);
}
