// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * This file holds code for reading the configuration file.
 */
module deqp.config.parser;

import watt = [watt.io.file, watt.xdg.basedir];
import toml = watt.toml;

import deqp.io;
import deqp.driver;


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
		s.testNamesFiles = [root["testNamesFile"].str()];
	}
	if (root.hasKey("resultsFile")) {
		s.resultsFile = root["resultsFile"].str();
	}
	if (root.hasKey("hastyBatchSize")) {
		s.batchSize = cast(u32) root["hastyBatchSize"].integer();
	}
	if (root.hasKey("batchSize")) {
		s.batchSize = cast(u32) root["batchSize"].integer();
	}
	if (root.hasKey("tempDir")) {
		s.tempDir = root["tempDir"].str();
	}
	if (root.hasKey("threads")) {
		s.threads = cast(u32) root["threads"].integer();
	}
	if (root.hasKey("printFailing")) {
		s.printFailing = root["printFailing"].boolean();
	}
	if (root.hasKey("regressionFile")) {
		s.resultsFile = root["regressionFile"].str();
	}
}
