// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * This file holds code for reading the configuration file.
 */
module deqp.config;

import deqp.driver;

import watt = [watt.io.file, watt.xdg.basedir];
import toml = watt.toml;


fn parseConfigFile(s: Settings)
{
	version (Linux) {
		configFile := watt.findConfigFile("dEQP/config.toml");
	} else {
		configFile: string[];
	}
		
	if (configFile is null) {
		return;
	}

	root := toml.parse(cast(string) watt.read(configFile[0]));
	if (root.type != toml.Value.Type.Table) {
		return;
	}

	if (root.hasKey("buildDir")) {
		s.buildDir = root["buildDir"].str();
	}
	if (root.hasKey("testNamesFile")) {
		s.testNamesFile = root["testNamesFile"].str();
	}
	if (root.hasKey("hastySize")) {
		s.hastySize = cast(u32) root["hastySize"].integer();
		s.hasty = true;
	}
}
