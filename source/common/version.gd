class_name GameVersion
extends RefCounted
## VERSION CONSTANTS - HARDWIRED VERSION CHECK
## ============================================
## This file is the SINGLE SOURCE OF TRUTH for runtime version validation.
## Both client and server MUST use this to validate connections.
##
## VERSION SYNC REQUIREMENTS:
##   - version.txt (deploy scripts read this)
##   - project.godot config/version (synced by deploy scripts)
##   - This file GAME_VERSION (MUST match version.txt)
##   - R2 version.json (created by deploy scripts)
##
## TO UPDATE VERSION:
##   1. Edit version.txt
##   2. Run deploy script (syncs project.godot and R2)
##   3. Update GAME_VERSION below to match
##
## The deploy scripts will FAIL if these are out of sync.


## CURRENT GAME VERSION - MUST MATCH version.txt
const GAME_VERSION: String = "0.1.5"

## Minimum compatible version (for backwards compatibility if needed)
const MIN_COMPATIBLE_VERSION: String = "0.1.5"


## Check if a version string matches current version
static func is_current_version(version: String) -> bool:
	return version == GAME_VERSION


## Check if a version is compatible (>= minimum)
static func is_compatible_version(version: String) -> bool:
	return _compare_versions(version, MIN_COMPATIBLE_VERSION) >= 0


## Compare two version strings
## Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
static func _compare_versions(v1: String, v2: String) -> int:
	var parts1 = v1.split(".")
	var parts2 = v2.split(".")

	for i in range(max(parts1.size(), parts2.size())):
		var p1 = int(parts1[i]) if i < parts1.size() else 0
		var p2 = int(parts2[i]) if i < parts2.size() else 0

		if p1 < p2:
			return -1
		elif p1 > p2:
			return 1

	return 0


## Get version mismatch error message
static func get_mismatch_message(client_version: String, server_version: String) -> String:
	return "Version mismatch! Client: %s, Server: %s. Please update your game." % [client_version, server_version]
