class_name BattleResultHandler
extends Node
## Battle Result Handler - Handles battle end, rewards, and scene transition
## Extracted from battle_window_v2.gd for modularity

signal battle_closed

# UI References (set via initialize)
var result_popup: Control = null
var result_title: Label = null
var xp_label: Label = null
var gold_label: Label = null
var action_buttons: Array = []

# Data references
var enemy_squad: Array = []

# UI Manager reference for turn info updates
var ui_manager = null


func initialize(refs: Dictionary):
	"""Initialize with UI references"""
	result_popup = refs.get("result_popup")
	result_title = refs.get("result_title")
	xp_label = refs.get("xp_label")
	gold_label = refs.get("gold_label")
	action_buttons = refs.get("action_buttons", [])
	ui_manager = refs.get("ui_manager")


func set_enemy_squad(squad: Array):
	"""Set enemy squad reference for rewards calculation"""
	enemy_squad = squad


func show_result(victory: bool, rewards: Dictionary = {}):
	"""Show battle result popup"""
	# Disable all action buttons
	for button in action_buttons:
		if button:
			button.disabled = true

	if victory:
		_show_victory(rewards)
	else:
		_show_defeat()


func _show_victory(server_rewards: Dictionary = {}):
	"""Display victory screen with rewards"""
	if ui_manager:
		ui_manager.update_turn_info("VICTORY! You defeated all enemies!")

	# Use server rewards if available, otherwise calculate locally
	var rewards = server_rewards if not server_rewards.is_empty() else calculate_rewards()
	
	# Map server keys (xp_gained) to UI keys (xp) if needed
	if rewards.has("xp_gained"): rewards["xp"] = rewards.get("xp_gained")
	if rewards.has("gold_gained"): rewards["gold"] = rewards.get("gold_gained")

	# Update popup text
	if result_title:
		result_title.text = "VICTORY!"
		result_title.modulate = Color(0.2, 1.0, 0.2)  # Green
	if xp_label:
		xp_label.text = "XP Gained: " + str(rewards.get("xp", 0))
	if gold_label:
		gold_label.text = "Gold Earned: " + str(rewards.get("gold", 0))

	# Show popup
	if result_popup:
		result_popup.visible = true


func _show_defeat():
	"""Display defeat screen"""
	if ui_manager:
		ui_manager.update_turn_info("DEFEAT! You were defeated...")

	# Update popup text
	if result_title:
		result_title.text = "DEFEAT!"
		result_title.modulate = Color(1.0, 0.2, 0.2)  # Red
	if xp_label:
		xp_label.text = "XP Gained: 0"
	if gold_label:
		gold_label.text = "Gold Earned: 0"

	# Show popup
	if result_popup:
		result_popup.visible = true


func calculate_rewards() -> Dictionary:
	"""Calculate XP and gold rewards based on enemies defeated"""
	var total_xp = 0
	var total_gold = 0

	# Base rewards per enemy (can be customized per enemy later)
	for enemy in enemy_squad:
		# Base XP: 10-50 depending on enemy level/stats
		var enemy_level = 1
		if enemy.has("level"):
			enemy_level = enemy.level
		var base_xp = 10 + (enemy_level * 5)
		total_xp += base_xp

		# Base gold: 5-25 depending on enemy level
		var base_gold = 5 + (enemy_level * 2)
		total_gold += base_gold

	return {"xp": total_xp, "gold": total_gold}


func on_continue_pressed():
	"""Handle continue button - return to game world"""
	if result_popup:
		result_popup.visible = false

	# Clear battle flag in GameState
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		game_state.set_meta("in_server_battle", false)

	# Emit signal before scene change
	battle_closed.emit()

	# Return to dev_client scene (position will be automatically restored by map_manager)
	get_tree().change_scene_to_file("res://dev_client.tscn")
