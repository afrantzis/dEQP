// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
module main;

import deqp.driver;


/*!
 * Instantiates a @ref deqp.driver.Driver
 * and calls @ref deqp.driver.Driver.run.
 */
fn main(args: string[]) i32
{
	d := new Driver();
	return d.run(args);
}
