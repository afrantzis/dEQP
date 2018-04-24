// Copyright 2018, Collabora Inc.
// SPDX-License-Identifier: BSL-1.0
/*!
 * This file holds code for reading the configuration file.
 */
module deqp.config;

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
		s.threads = cast(u32) root["threads"].integer();
	}
}

fn printConfig(s: Settings)
{
	info(" :: Config");
	info("\ttestNamesFile  = '%s'"	, s.testNamesFile);
	info("\tctsBuildDir    = '%s'", s.ctsBuildDir);
	info("\thastyBatchSize = %s", s.hastyBatchSize);
	info("\tthreads        = %s", s.threads);
	info("\tresultsFile    = '%s'", s.resultsFile);
	info("\ttempDir        = '%s'", s.tempDir);
}
