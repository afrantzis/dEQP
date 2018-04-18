// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * This file holds code for reading the configuration file.
 */
module deqp.config;

import deqp.driver;

import watt = [watt.io.file, watt.xdg.basedir];
import toml = watt.toml;

enum ConfigFile = "dEQP/config.toml";

fn parseConfigFile(s: Settings)
{
	version (Linux) {
		configFile := watt.findConfigFile(ConfigFile);
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

	if (root.hasKey("ctsBuildDir")) {
		s.ctsBuildDir = root["ctsBuildDir"].str();
	}
	if (root.hasKey("testNamesFile")) {
		s.testNamesFile = root["testNamesFile"].str();
	}
	if (root.hasKey("resultsFile")) {
		s.resultsFile = root["resultsFile"].str();
	}
	if (root.hasKey("hastyBatchSize")) {
		s.hastyBatchSize = cast(u32) root["hastyBatchSize"].integer();
		s.hasty = true;
	}
	if (root.hasKey("threads")) {
		s.numThreads = cast(u32) root["threads"].integer();
	}
}
