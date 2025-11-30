extends Node

## Characterization Test - File Organization Baseline
## Purpose: Capture baseline behavior before file reorganization to detect breakage
## Created: 2025-11-14
## Test Type: Integration Test (Golden Master pattern)
##
## This test verifies that:
## 1. All critical client scene files are accessible
## 2. Main entry points load without errors
## 3. No broken preload/import statements exist
## 4. Gateway UI initializes properly
## 5. Key managers can be instantiated
##
## BASELINE BEHAVIOR: Document any failures here as "expected" during reorganization

var test_results: Array = []
var tests_passed: int = 0
var tests_failed: int = 0
var baseline_failures: Array = []  # Track known baseline failures

func _ready():
	print("\n" + "=".repeat(70))
	print("CHARACTERIZATION TEST: FILE ORGANIZATION BASELINE")
	print("=".repeat(70))
	print("Purpose: Capture baseline state before file reorganization")
	print("Date: " + str(Time.get_ticks_msec()))
	print("=".repeat(70) + "\n")

	run_all_tests()
	print_test_summary()

	# Cleanup
	queue_free()


func run_all_tests():
	"""Execute all characterization tests"""
	print("\n--- PHASE 1: Core Files Existence ---\n")
	test_client_launcher_exists()
	test_client_main_exists()
	test_login_screen_exists()
	test_gateway_files_exist()
	test_manager_files_exist()

	print("\n--- PHASE 2: Resource Path Validation ---\n")
	test_critical_paths_with_resource_loader()
	test_scene_file_paths()

	print("\n--- PHASE 3: Script Loading (Preload Safety) ---\n")
	test_launcher_script_loads()
	test_gateway_script_loads()
	test_manager_scripts_load()

	print("\n--- PHASE 4: Scene Instantiation ---\n")
	test_login_scene_instantiation()
	test_gateway_scene_instantiation()
	test_character_select_scene_instantiation()

	print("\n--- PHASE 5: Key Manager References ---\n")
	test_manager_references_in_gateway()


## ========== PHASE 1: File Existence Tests ==========

func test_client_launcher_exists():
	"""Verify client_launcher.gd exists at expected path"""
	var test_name = "client_launcher.gd exists"
	var script_path = "res://source/client/client_launcher.gd"

	if ResourceLoader.exists(script_path, "Script"):
		record_pass(test_name, script_path)
	else:
		record_fail(test_name, "File not found: " + script_path)


func test_client_main_exists():
	"""Verify client_main.gd exists at expected path"""
	var test_name = "client_main.gd exists"
	var script_path = "res://source/client/client_main.gd"

	if ResourceLoader.exists(script_path, "Script"):
		record_pass(test_name, script_path)
	else:
		record_fail(test_name, "File not found: " + script_path)


func test_login_screen_exists():
	"""Verify login_screen files exist"""
	var test_name = "login_screen files exist"
	var gd_path = "res://source/client/ui/login_screen.gd"
	var scene_path = "res://source/client/ui/login_screen.tscn"

	var gd_exists = ResourceLoader.exists(gd_path, "Script")
	var scene_exists = ResourceLoader.exists(scene_path, "PackedScene")

	if gd_exists and scene_exists:
		record_pass(test_name, "Both .gd and .tscn files exist")
	else:
		var missing = []
		if not gd_exists:
			missing.append(gd_path)
		if not scene_exists:
			missing.append(scene_path)
		record_fail(test_name, "Missing files: " + str(missing))


func test_gateway_files_exist():
	"""Verify gateway files exist"""
	var test_name = "gateway files exist"
	var script_path = "res://source/client/gateway/gateway.gd"
	var scene_path = "res://source/client/gateway/gateway.tscn"

	var script_exists = ResourceLoader.exists(script_path, "Script")
	var scene_exists = ResourceLoader.exists(scene_path, "PackedScene")

	if script_exists and scene_exists:
		record_pass(test_name, "Both gateway.gd and gateway.tscn exist")
	else:
		var missing = []
		if not script_exists:
			missing.append(script_path)
		if not scene_exists:
			missing.append(scene_path)
		record_fail(test_name, "Missing gateway files: " + str(missing))


func test_manager_files_exist():
	"""Verify critical manager files exist"""
	var test_name = "manager files exist"
	var managers = [
		"res://source/client/managers/animation_control_manager.gd",
		"res://source/client/managers/character_setup_manager.gd",
		"res://source/client/managers/map_manager.gd",
		"res://source/client/managers/input_handler_manager.gd",
		"res://source/client/managers/ui_panel_manager.gd",
		"res://source/client/managers/multiplayer_manager.gd",
	]

	var missing = []
	for manager_path in managers:
		if not ResourceLoader.exists(manager_path, "Script"):
			missing.append(manager_path)

	if missing.is_empty():
		record_pass(test_name, "All critical managers exist")
	else:
		record_fail(test_name, "Missing managers: " + str(missing))


## ========== PHASE 2: Resource Path Validation ==========

func test_critical_paths_with_resource_loader():
	"""Test paths using ResourceLoader.exists() - core validation"""
	var test_name = "critical paths accessible via ResourceLoader"

	var critical_paths = [
		# Client entry points
		{"path": "res://source/client/client_launcher.gd", "type": "Script"},
		{"path": "res://source/client/client_launcher.tscn", "type": "PackedScene"},
		{"path": "res://source/client/client_main.gd", "type": "Script"},
		{"path": "res://source/client/client_main.tscn", "type": "PackedScene"},

		# UI screens
		{"path": "res://source/client/ui/login_screen.gd", "type": "Script"},
		{"path": "res://source/client/ui/login_screen.tscn", "type": "PackedScene"},
		{"path": "res://source/client/ui/character_select_screen.gd", "type": "Script"},
		{"path": "res://source/client/ui/character_select_screen.tscn", "type": "PackedScene"},

		# Gateway
		{"path": "res://source/client/gateway/gateway.gd", "type": "Script"},
		{"path": "res://source/client/gateway/gateway.tscn", "type": "PackedScene"},

		# Common resources
		{"path": "res://source/common/utils/credentials_utils.gd", "type": "Script"},
		{"path": "res://source/common/network/gateway_api.gd", "type": "Script"},
	]

	var failed_paths = []
	for path_check in critical_paths:
		if not ResourceLoader.exists(path_check["path"], path_check["type"]):
			failed_paths.append(path_check["path"])

	if failed_paths.is_empty():
		record_pass(test_name, "All %d critical paths accessible" % critical_paths.size())
	else:
		record_fail(test_name, "Inaccessible paths: " + str(failed_paths))


func test_scene_file_paths():
	"""Verify all scene files are accessible"""
	var test_name = "all scene files accessible"

	var scene_paths = [
		"res://source/client/ui/login_screen.tscn",
		"res://source/client/ui/character_select_screen.tscn",
		"res://source/client/ui/chat_ui.tscn",
		"res://source/client/ui/settings_screen.tscn",
		"res://source/client/ui/ui.tscn",
		"res://source/client/gateway/gateway.tscn",
		"res://source/client/client_main.tscn",
		"res://source/client/client_launcher.tscn",
	]

	var failed_scenes = []
	for scene_path in scene_paths:
		if not ResourceLoader.exists(scene_path, "PackedScene"):
			failed_scenes.append(scene_path)

	if failed_scenes.is_empty():
		record_pass(test_name, "%d scene files verified" % scene_paths.size())
	else:
		record_fail(test_name, "Missing scenes: " + str(failed_scenes))


## ========== PHASE 3: Script Loading (Preload Safety) ==========

func test_launcher_script_loads():
	"""Verify client_launcher.gd script loads without preload errors"""
	var test_name = "client_launcher.gd loads"

	var result = safe_load_script("res://source/client/client_launcher.gd")
	if result["success"]:
		record_pass(test_name, "Script loaded successfully")
	else:
		record_fail(test_name, "Load error: " + result["error"])


func test_gateway_script_loads():
	"""Verify gateway.gd script loads without preload errors"""
	var test_name = "gateway.gd loads"

	var result = safe_load_script("res://source/client/gateway/gateway.gd")
	if result["success"]:
		record_pass(test_name, "Gateway script loaded successfully")
	else:
		record_fail(test_name, "Load error: " + result["error"])
		baseline_failures.append("gateway.gd preload error: " + result["error"])


func test_manager_scripts_load():
	"""Verify critical manager scripts load"""
	var test_name = "manager scripts load"

	var managers = [
		"res://source/client/managers/animation_control_manager.gd",
		"res://source/client/managers/character_setup_manager.gd",
		"res://source/client/managers/map_manager.gd",
		"res://source/client/managers/input_handler_manager.gd",
		"res://source/client/managers/ui_panel_manager.gd",
	]

	var failed_managers = []
	for manager_path in managers:
		var result = safe_load_script(manager_path)
		if not result["success"]:
			failed_managers.append({"path": manager_path, "error": result["error"]})

	if failed_managers.is_empty():
		record_pass(test_name, "%d manager scripts load successfully" % managers.size())
	else:
		var error_msg = "Failed managers: " + str(failed_managers)
		record_fail(test_name, error_msg)


## ========== PHASE 4: Scene Instantiation ==========

func test_login_scene_instantiation():
	"""Verify login_screen.tscn can be loaded and instantiated"""
	var test_name = "login_screen.tscn instantiation"

	var result = safe_load_scene("res://source/client/ui/login_screen.tscn")
	if result["success"] and result["scene"] != null:
		record_pass(test_name, "Scene instantiated successfully")
	else:
		record_fail(test_name, "Instantiation error: " + result["error"])


func test_gateway_scene_instantiation():
	"""Verify gateway.tscn can be loaded and instantiated"""
	var test_name = "gateway.tscn instantiation"

	var result = safe_load_scene("res://source/client/gateway/gateway.tscn")
	if result["success"] and result["scene"] != null:
		record_pass(test_name, "Gateway scene instantiated successfully")
	else:
		record_fail(test_name, "Instantiation error: " + result["error"])


func test_character_select_scene_instantiation():
	"""Verify character_select_screen.tscn can be loaded"""
	var test_name = "character_select_screen.tscn instantiation"

	var result = safe_load_scene("res://source/client/ui/character_select_screen.tscn")
	if result["success"] and result["scene"] != null:
		record_pass(test_name, "Character select scene instantiated successfully")
	else:
		record_fail(test_name, "Instantiation error: " + result["error"])


## ========== PHASE 5: Key Manager References ==========

func test_manager_references_in_gateway():
	"""Verify gateway.gd can reference required utilities"""
	var test_name = "gateway.gd dependencies"

	var result = safe_load_script("res://source/client/gateway/gateway.gd")
	if result["success"]:
		# Check that preloaded resources exist
		var creds_utils = "res://source/common/utils/credentials_utils.gd"
		var gateway_api = "res://source/common/network/gateway_api.gd"

		var creds_exists = ResourceLoader.exists(creds_utils, "Script")
		var api_exists = ResourceLoader.exists(gateway_api, "Script")

		if creds_exists and api_exists:
			record_pass(test_name, "All gateway dependencies accessible")
		else:
			var missing = []
			if not creds_exists:
				missing.append(creds_utils)
			if not api_exists:
				missing.append(gateway_api)
			record_fail(test_name, "Missing dependencies: " + str(missing))
	else:
		record_fail(test_name, "Could not verify - gateway script failed to load")


## ========== Helper Functions ==========

func safe_load_script(script_path: String) -> Dictionary:
	"""Safely load a script using null checks"""
	var script = load(script_path)
	if script == null:
		return {
			"success": false,
			"error": "load() returned null - file not found or invalid",
			"script": null
		}
	return {
		"success": true,
		"error": "",
		"script": script
	}


func safe_load_scene(scene_path: String) -> Dictionary:
	"""Safely load a scene using null checks"""
	var scene = load(scene_path)
	if scene == null:
		return {
			"success": false,
			"error": "load() returned null - file not found or invalid",
			"scene": null
		}

	var instance = scene.instantiate()
	if instance == null:
		return {
			"success": false,
			"error": "instantiate() returned null",
			"scene": null
		}

	return {
		"success": true,
		"error": "",
		"scene": instance
	}


func record_pass(test_name: String, detail: String = ""):
	"""Record a passing test"""
	tests_passed += 1
	var message = "[PASS] " + test_name
	if detail:
		message += " - " + detail
	print(message)
	test_results.append({
		"name": test_name,
		"status": "PASS",
		"detail": detail
	})


func record_fail(test_name: String, detail: String = ""):
	"""Record a failing test"""
	tests_failed += 1
	var message = "[FAIL] " + test_name
	if detail:
		message += " - " + detail
	print(message)
	test_results.append({
		"name": test_name,
		"status": "FAIL",
		"detail": detail
	})


func print_test_summary():
	"""Print comprehensive test summary"""
	print("\n" + "=".repeat(70))
	print("TEST SUMMARY")
	print("=".repeat(70))
	print("Total Tests: %d" % test_results.size())
	print("Passed: %d" % tests_passed)
	print("Failed: %d" % tests_failed)
	print("Success Rate: %.1f%%" % (float(tests_passed) / test_results.size() * 100.0))
	print("=".repeat(70))

	if tests_failed > 0:
		print("\nFAILED TESTS:")
		for result in test_results:
			if result["status"] == "FAIL":
				print("  - %s" % result["name"])
				if result["detail"]:
					print("    Detail: %s" % result["detail"])

	if not baseline_failures.is_empty():
		print("\nKNOWN BASELINE FAILURES (expected before reorganization):")
		for failure in baseline_failures:
			print("  - %s" % failure)

	print("\n" + "=".repeat(70))
	print("STATUS: %s" % ("ALL TESTS PASSED" if tests_failed == 0 else "TESTS FAILED"))
	print("=".repeat(70) + "\n")
