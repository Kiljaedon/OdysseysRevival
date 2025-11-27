class_name BattleTurnExecutor
extends Node
## Battle Turn Executor - Handles turn execution for all unit types
## Extracted from battle_window_v2.gd for modularity
##
## CRITICAL FIX14 NOTE:
## For server battles, execute_player_attack() sends action via network_client
## but does NOT await the response here. The response comes back via
## network_client's signals (action_result_received) which are handled
## by the main battle_window. This prevents the freeze bug where
## enemy results could overwrite player results.

signal turn_complete
signal battle_ended(victory: bool)

# References (set via initialize)
var ui_manager = null
var animations = null
var combat_controller = null
var network_client = null
var floating_overlays = null

# Squad references (set via set_squads)
var enemy_squad: Array = []
var ally_squad: Array = []
var player_character: Dictionary = {}

# Callback for end_battle (since we can't directly call it)
var end_battle_callback: Callable


func initialize(refs: Dictionary):
	"""Initialize with required references"""
	ui_manager = refs.get("ui_manager")
	animations = refs.get("animations")
	combat_controller = refs.get("combat_controller")
	network_client = refs.get("network_client")
	floating_overlays = refs.get("floating_overlays")

	if refs.has("end_battle_callback"):
		end_battle_callback = refs.get("end_battle_callback")


func set_squads(p_enemy_squad: Array, p_ally_squad: Array, p_player_character: Dictionary):
	"""Set squad references - call after squads are loaded"""
	enemy_squad = p_enemy_squad
	ally_squad = p_ally_squad
	player_character = p_player_character


func execute_player_turn():
	"""Execute player's queued action"""
	var queued = combat_controller.get_player_queued_action()
	var action = queued.get("action", "defend")
	var target_id = queued.get("target_id", -1)

	if action == "attack" and target_id >= 0:
		await execute_player_attack(target_id)
	else:
		# Defend or invalid action
		var player_name = player_character.get("character_name", "Player")
		ui_manager.update_turn_info("🛡️ %s's turn!" % player_name)
		await get_tree().create_timer(0.5).timeout
		ui_manager.update_turn_info("🛡️ %s defends!" % player_name)
		await get_tree().create_timer(1.0).timeout
		combat_controller.advance_turn()


func execute_player_attack(target_index: int):
	"""Player attacks enemy - send to server for authoritative calculation"""
	var player_name = player_character.get("character_name", "Player")
	var target = enemy_squad[target_index]
	var target_name = target.get("character_name", "Enemy")

	# SHOW whose turn it is
	ui_manager.update_turn_info("⚔️ %s's turn!" % player_name)
	await get_tree().create_timer(0.5).timeout

	# PLAY ATTACK ANIMATION
	var ally_sprites = ui_manager.get_ally_sprites()
	var enemy_sprites = ui_manager.get_enemy_sprites()
	var player_sprite = ally_sprites[0] if ally_sprites.size() > 0 else null
	var target_sprite = enemy_sprites[target_index] if target_index < enemy_sprites.size() else null
	if player_sprite and target_sprite and animations:
		animations.play_attack_animation(player_sprite, player_character, "attack_left", target_sprite)
		await animations.animation_completed

	# FOR SERVER BATTLES: Send action to server
	# NOTE: Response is handled by network_client signals, NOT awaited here (FIX14)
	if combat_controller.is_server_battle and network_client:
		network_client.send_player_action("attack", target_index)
		# Response handled by _on_server_result_received via signal in battle_window
	else:
		# LOCAL BATTLE: Client-side calculation
		var damage = _calculate_damage(player_character, target, 0, target_index, false)
		target.hp -= damage
		target.hp = max(0, target.hp)

		ui_manager.update_turn_info("⚔️ %s attacks %s for %d damage!" % [player_name, target_name, damage])
		ui_manager.update_enemy_ui(target_index)
		floating_overlays.update_overlays()

		if target.hp <= 0:
			var enemy_panels = ui_manager.get_enemy_panels() if ui_manager else []
			if target_index < enemy_panels.size() and enemy_panels[target_index]:
				enemy_panels[target_index].visible = false
			floating_overlays.hide_overlay(true, target_index)

	# Check battle end
	var battle_end = combat_controller.check_battle_end()
	if battle_end.ended:
		_handle_battle_end(battle_end.victory)
		return

	await get_tree().create_timer(1.5).timeout
	combat_controller.advance_turn()


func execute_ally_turn(ally_data: Dictionary):
	"""Execute ally NPC's turn (AI)"""
	var ally_name = ally_data.get("character_name", "Unknown")

	# SHOW whose turn it is
	ui_manager.update_turn_info("⚔️ %s's turn!" % ally_name)
	await get_tree().create_timer(0.5).timeout

	# Simple AI: attack random enemy
	var alive_enemies = []
	for i in range(enemy_squad.size()):
		if enemy_squad[i].get("hp", 0) > 0:
			alive_enemies.append(i)

	if alive_enemies.is_empty():
		combat_controller.advance_turn()
		return

	var target_index = alive_enemies[randi() % alive_enemies.size()]
	var target = enemy_squad[target_index]

	# PLAY ATTACK ANIMATION
	var ally_index = ally_squad.find(ally_data)
	var ally_sprites = ui_manager.get_ally_sprites()
	var enemy_sprites = ui_manager.get_enemy_sprites()
	var ally_sprite = ally_sprites[ally_index] if ally_index >= 0 and ally_index < ally_sprites.size() else null
	var target_sprite = enemy_sprites[target_index] if target_index < enemy_sprites.size() else null
	if ally_sprite and target_sprite and animations:
		animations.play_attack_animation(ally_sprite, ally_data, "attack_left", target_sprite)
		await animations.animation_completed

	# Calculate damage with position indices for range penalty system
	var damage = _calculate_damage(ally_data, target, ally_index, target_index, false)

	target.hp -= damage
	target.hp = max(0, target.hp)

	var target_name = target.get("character_name", "Enemy")
	ui_manager.update_turn_info("⚔️ %s attacks %s for %d damage!" % [ally_name, target_name, damage])
	ui_manager.update_enemy_ui(target_index)
	floating_overlays.update_overlays()

	# Check if target defeated
	if target.hp <= 0:
		var enemy_panels = ui_manager.get_enemy_panels() if ui_manager else []
		if target_index < enemy_panels.size() and enemy_panels[target_index]:
			enemy_panels[target_index].visible = false
		floating_overlays.hide_overlay(true, target_index)

	# Check battle end
	var battle_end = combat_controller.check_battle_end()
	if battle_end.ended:
		_handle_battle_end(battle_end.victory)
		return

	await get_tree().create_timer(1.5).timeout
	combat_controller.advance_turn()


func execute_enemy_turn(enemy_data: Dictionary):
	"""Execute enemy's turn (AI)"""
	var enemy_name = enemy_data.get("character_name", "Unknown")

	# SHOW whose turn it is
	ui_manager.update_turn_info("💀 %s's turn!" % enemy_name)
	await get_tree().create_timer(0.5).timeout

	# Simple AI: attack player (ally index 0)
	var player_index = 0
	var player_name = ally_squad[player_index].get("character_name", "Player")

	# PLAY ATTACK ANIMATION
	var enemy_index = enemy_squad.find(enemy_data)
	var enemy_sprites = ui_manager.get_enemy_sprites()
	var ally_sprites = ui_manager.get_ally_sprites()
	var enemy_sprite = enemy_sprites[enemy_index] if enemy_index >= 0 and enemy_index < enemy_sprites.size() else null
	var player_sprite = ally_sprites[player_index] if player_index < ally_sprites.size() else null
	if enemy_sprite and player_sprite and animations:
		animations.play_attack_animation(enemy_sprite, enemy_data, "attack_right", player_sprite)
		await animations.animation_completed

	# Calculate damage with position indices for range penalty system
	var damage = _calculate_damage(enemy_data, ally_squad[player_index], enemy_index, player_index, true)

	ally_squad[player_index].hp -= damage
	ally_squad[player_index].hp = max(0, ally_squad[player_index].hp)

	ui_manager.update_turn_info("💀 %s attacks %s for %d damage!" % [enemy_name, player_name, damage])
	ui_manager.update_ally_ui(player_index)
	floating_overlays.update_overlays()

	# Check if player defeated
	if ally_squad[player_index].hp <= 0:
		var ally_panels = ui_manager.get_ally_panels() if ui_manager else []
		if player_index < ally_panels.size() and ally_panels[player_index]:
			ally_panels[player_index].visible = false
		floating_overlays.hide_overlay(false, player_index)

	# Check battle end
	var battle_end = combat_controller.check_battle_end()
	if battle_end.ended:
		_handle_battle_end(battle_end.victory)
		return

	await get_tree().create_timer(1.5).timeout
	combat_controller.advance_turn()


func _handle_battle_end(victory: bool):
	"""Handle battle end - call callback or emit signal"""
	if end_battle_callback.is_valid():
		end_battle_callback.call(victory)
	else:
		battle_ended.emit(victory)


func _calculate_damage(attacker: Dictionary, defender: Dictionary, attacker_index: int, defender_index: int, is_attacker_enemy: bool) -> int:
	"""Delegate to BattleDamageCalculator"""
	return BattleDamageCalculator.calculate_damage(attacker, defender, attacker_index, defender_index, is_attacker_enemy)
