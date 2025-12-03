extends Node
## Test script for Realtime Battle Refactor

var realtime_battle_scene_path = "res://scenes/battle/realtime_battle.tscn"
var multiplayer_manager_path = "res://source/client/managers/multiplayer_manager.gd"

func _ready():
	print("--- Running Combat Refactor Test ---")
	test_scene_instantiation_and_nodes()
	test_hud_update()
	test_multiplayer_manager_integration()
	print("--- Combat Refactor Test Complete ---")
	get_tree().quit()

func test_scene_instantiation_and_nodes():
	print("Test: Scene Instantiation and Node Existence")
	var battle_scene_res = preload(realtime_battle_scene_path)
	var battle_instance = battle_scene_res.instantiate()
	add_child(battle_instance)

	assert(battle_instance != null, "RealtimeBattle scene should instantiate")
	assert(battle_instance.name == "RealtimeBattle", "Battle scene should be named 'RealtimeBattle'")

	assert(battle_instance.has_node("ArenaRenderer"), "ArenaRenderer should exist")
	assert(battle_instance.has_node("UnitsContainer"), "UnitsContainer should exist")
	assert(battle_instance.has_node("BattleCamera"), "BattleCamera should exist")
	assert(battle_instance.has_node("BattleUI"), "BattleUI CanvasLayer should exist")

	var player_hud = battle_instance.get_node("BattleUI/PlayerHUD")
	assert(player_hud != null, "PlayerHUD should exist")
	assert(player_hud.has_node("HUDBg"), "PlayerHUD Background should exist")
	assert(player_hud.has_node("PlayerNameLabel"), "PlayerNameLabel should exist")
	assert(player_hud.has_node("HPBar"), "HPBar should exist")
	assert(player_hud.has_node("MPBar"), "MPBar should exist")
	assert(player_hud.has_node("EPBar"), "EPBar should exist")

	battle_instance.queue_free()
	print("Test: Scene Instantiation and Node Existence - PASSED")

func test_hud_update():
	print("Test: HUD Update Functionality")
	var battle_scene_res = preload(realtime_battle_scene_path)
	var battle_instance = battle_scene_res.instantiate()
	add_child(battle_instance)

	var hp_bar = battle_instance.get_node("BattleUI/PlayerHUD/HPBar")
	var mp_bar = battle_instance.get_node("BattleUI/PlayerHUD/MPBar")
	var ep_bar = battle_instance.get_node("BattleUI/PlayerHUD/EPBar")
	var name_label = battle_instance.get_node("BattleUI/PlayerHUD/PlayerNameLabel")

	# Mock data for update
	var mock_hp = 50
	var mock_max_hp = 100
	var mock_mp = 25
	var mock_max_mp = 50
	var mock_ep = 75
	var mock_max_ep = 75
	var mock_name = "TestPlayer"

	battle_instance.update_player_hud(mock_hp, mock_max_hp, mock_mp, mock_max_mp, mock_ep, mock_max_ep, mock_name)

	assert(hp_bar.value == mock_hp, "HPBar value should update")
	assert(hp_bar.max_value == mock_max_hp, "HPBar max_value should update")
	assert(mp_bar.value == mock_mp, "MPBar value should update")
	assert(mp_bar.max_value == mock_max_mp, "MPBar max_value should update")
	assert(ep_bar.value == mock_ep, "EPBar value should update")
	assert(ep_bar.max_value == mock_max_ep, "EPBar max_value should update")
	assert(name_label.text == mock_name, "PlayerNameLabel text should update")

	battle_instance.queue_free()
	print("Test: HUD Update Functionality - PASSED")

func test_multiplayer_manager_integration():
	print("Test: Multiplayer Manager Integration")
	# Create a mock root node for the multiplayer manager
	var mock_root = Node.new()
	mock_root.name = "Root"
	add_child(mock_root)

	var multiplayer_manager = preload(multiplayer_manager_path).instantiate()
	multiplayer_manager.name = "MultiplayerManager"
	mock_root.add_child(multiplayer_manager)

	# Manually add the RealtimeBattle scene to the mock root, as RealtimeBattleLauncher would
	var battle_scene_res = preload(realtime_battle_scene_path)
	var battle_instance = battle_scene_res.instantiate()
	battle_instance.name = "RealtimeBattle"
	mock_root.add_child(battle_instance)

	var mock_results = {"damage": 10}
	var original_print = print
	var log_captured = []
	
	# Override print to capture output for assertion
	# This is a bit hacky but allows checking if the error message is NOT printed
	# Or if the correct message IS printed.
	# Note: In a real test framework, one would use proper mocks or signals for better isolation.
	func mock_print(args):
		log_captured.append(str(args))
		original_print(args) # Still print to console for debugging

	print = mock_print

	multiplayer_manager.handle_combat_round_results(1, mock_results)

	print = original_print # Restore original print

	# Check if the error message for "BattleWindow not found!" was NOT printed
	var error_found = false
	for log_entry in log_captured:
		if "ERROR: BattleWindow not found!" in log_entry:
			error_found = true
			break
	
	assert(not error_found, "ERROR: BattleWindow not found! should NOT be printed")

	# If the battle_instance has a receive_round_results method, we could call and check it.
	# For now, we confirm the error message is gone.
	if battle_instance.has_method("receive_round_results"):
		print("Note: RealtimeBattle has 'receive_round_results' method. Further testing needed to verify data flow.")
	else:
		print("Note: RealtimeBattle does NOT have 'receive_round_results' method. Manager forwards but target might not process.")

	mock_root.queue_free()
	print("Test: Multiplayer Manager Integration - PASSED")

func assert(condition: bool, message: String):
	if not condition:
		push_error(message)
		get_tree().quit()
	else:
		print("  ✓ " + message)
