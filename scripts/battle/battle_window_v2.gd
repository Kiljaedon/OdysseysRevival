extends Control
## Battle Window V2 - Main Coordinator
## Integrates all modular battle subsystems

# Subsystem instances
var data_loader: BattleDataLoader
var combat_controller: BattleCombatController
var ui_manager: BattleUIManager
var animations: BattleAnimations
var network_client: BattleNetworkClient
var choreography: BattleChoreography
var node_provider: BattleNodeProvider
var floating_overlays: BattleFloatingOverlays
var input_handler: BattleInputHandler
var turn_executor: BattleTurnExecutor
var result_handler: BattleResultHandler

# Squad data
var enemy_squad: Array = []
var ally_squad: Array = []
var player_character: Dictionary = {}

# UI Node references
@onready var enemy_panel_1 = $BattleContainer/CombatArea/EnemyArea/EnemyPanel1
@onready var enemy_panel_2 = $BattleContainer/CombatArea/EnemyArea/EnemyPanel2
@onready var enemy_panel_3 = $BattleContainer/CombatArea/EnemyArea/EnemyPanel3
@onready var enemy_panel_4 = $BattleContainer/CombatArea/EnemyArea/EnemyPanel4
@onready var enemy_panel_5 = $BattleContainer/CombatArea/EnemyArea/EnemyPanel5
@onready var enemy_panel_6 = $BattleContainer/CombatArea/EnemyArea/EnemyPanel6

@onready var ally_panel_1 = $BattleContainer/CombatArea/PlayerArea/Ally1Panel
@onready var ally_panel_2 = $BattleContainer/CombatArea/PlayerArea/Ally2Panel
@onready var ally_panel_3 = $BattleContainer/CombatArea/PlayerArea/Ally3Panel
@onready var ally_panel_4 = $BattleContainer/CombatArea/PlayerArea/Ally4Panel
@onready var ally_panel_5 = $BattleContainer/CombatArea/PlayerArea/Ally5Panel
@onready var ally_panel_6 = $BattleContainer/CombatArea/PlayerArea/Ally6Panel

# Action buttons
@onready var attack_button = $UIPanel/UIArea/ActionButtons/AttackButton
@onready var defend_button = $UIPanel/UIArea/ActionButtons/DefendButton
@onready var skills_button = $UIPanel/UIArea/ActionButtons/SkillsButton
@onready var items_button = $UIPanel/UIArea/ActionButtons/ItemsButton

# Action button navigation (managed by input_handler)

# UI elements
@onready var ui_panel = $UIPanel
@onready var turn_info = $UIPanel/UIArea/TurnInfo
@onready var target_cursor = $TargetCursor

# Layout buttons
@onready var save_layout_button = $UIPanel/UIArea/LayoutButtons/SaveLayoutButton
@onready var reset_layout_button = $UIPanel/UIArea/LayoutButtons/ResetLayoutButton
@onready var save_ui_button = $SaveUIButton

# Result Popup References
@onready var result_popup = $ResultPopup
@onready var result_title = $ResultPopup/PopupContent/ResultTitle
@onready var xp_label = $ResultPopup/PopupContent/XPLabel
@onready var gold_label = $ResultPopup/PopupContent/GoldLabel
@onready var continue_button = $ResultPopup/PopupContent/ContinueButton

## ========== INITIALIZATION ==========

func _ready():
	"""Initialize battle window and all subsystems"""

	# Initialize subsystems
	initialize_subsystems()

	# Align all panels to perfect grid positions
	choreography.auto_align_all_panels()

	# Load saved UI layout (if exists)
	load_ui_layout()

	# Make UIPanel visible (battle_panel.gd hides panels by default)
	if ui_panel:
		ui_panel.visible = true

	# Initialize input handler with action buttons
	var action_buttons = [attack_button, defend_button, skills_button, items_button]
	input_handler.initialize(combat_controller, ui_manager, action_buttons, result_popup)

	# Create floating overlay containers (will be populated after squads load)
	floating_overlays.create_overlays(self)

	# Hide developer title bars on all panels (delay slightly to ensure panels are ready)
	await get_tree().process_frame
	floating_overlays.hide_panel_title_bars(get_enemy_panels, get_ally_panels)

	# Hide character name labels (they block the view)
	floating_overlays.hide_name_labels(get_enemy_names, get_ally_names)

	# Wire up signal connections
	connect_subsystem_signals()

	# Setup battle from GameState or local data
	setup_battle()

func initialize_subsystems():
	"""Create and initialize all battle subsystems"""

	# Create subsystem instances
	combat_controller = BattleCombatController.new()
	ui_manager = BattleUIManager.new()
	animations = BattleAnimations.new()
	network_client = BattleNetworkClient.new()
	choreography = BattleChoreography.new()
	node_provider = BattleNodeProvider.new()
	floating_overlays = BattleFloatingOverlays.new()
	input_handler = BattleInputHandler.new()
	turn_executor = BattleTurnExecutor.new()
	result_handler = BattleResultHandler.new()

	# Add as children
	add_child(combat_controller)
	add_child(ui_manager)
	add_child(animations)
	add_child(network_client)
	add_child(choreography)
	add_child(node_provider)
	add_child(floating_overlays)
	add_child(input_handler)
	add_child(turn_executor)
	add_child(result_handler)

	# Initialize BattleNodeProvider with panel references AND all UI element references
	var enemy_panel_array = [enemy_panel_1, enemy_panel_2, enemy_panel_3, enemy_panel_4, enemy_panel_5, enemy_panel_6]
	var ally_panel_array = [ally_panel_1, ally_panel_2, ally_panel_3, ally_panel_4, ally_panel_5, ally_panel_6]

	# Collect UI references DIRECTLY from scene nodes (NOT through node_provider which isn't initialized yet)
	# Extract sprites from panels
	var enemy_sprites_array = []
	var ally_sprites_array = []
	for i in range(enemy_panel_array.size()):
		var panel = enemy_panel_array[i]
		if panel:
			var unit_node = panel.get_node_or_null("EnemyUnit%d" % (i + 1))
			if unit_node:
				var sprite = unit_node.get_node_or_null("EnemySprite%d" % (i + 1))
				if sprite:
					enemy_sprites_array.append(sprite)

	for i in range(ally_panel_array.size()):
		var panel = ally_panel_array[i]
		if panel:
			var unit_node = panel.get_node_or_null("Ally%dUnit" % (i + 1))
			if unit_node:
				var sprite = unit_node.get_node_or_null("Ally%dSprite" % (i + 1))
				if sprite:
					ally_sprites_array.append(sprite)

	# Extract all other UI elements similarly
	var enemy_names_array = []
	var ally_names_array = []
	var enemy_hp_bars_array = []
	var ally_hp_bars_array = []
	var enemy_hp_labels_array = []
	var ally_hp_labels_array = []
	var enemy_mp_bars_array = []
	var ally_mp_bars_array = []
	var enemy_mp_labels_array = []
	var ally_mp_labels_array = []
	var enemy_energy_bars_array = []
	var ally_energy_bars_array = []
	var enemy_energy_labels_array = []
	var ally_energy_labels_array = []

	for i in range(enemy_panel_array.size()):
		var panel = enemy_panel_array[i]
		if panel:
			var unit_node = panel.get_node_or_null("EnemyUnit%d" % (i + 1))
			if unit_node:
				var name_label = unit_node.get_node_or_null("EnemyName%d" % (i + 1))
				if name_label:
					enemy_names_array.append(name_label)
				var hp_bar = unit_node.get_node_or_null("EnemyHPBar%d" % (i + 1))
				if hp_bar:
					enemy_hp_bars_array.append(hp_bar)
				var hp_label = unit_node.get_node_or_null("EnemyHPLabel%d" % (i + 1))
				if hp_label:
					enemy_hp_labels_array.append(hp_label)
				var mp_bar = unit_node.get_node_or_null("EnemyMPBar%d" % (i + 1))
				if mp_bar:
					enemy_mp_bars_array.append(mp_bar)
				var mp_label = unit_node.get_node_or_null("EnemyMPLabel%d" % (i + 1))
				if mp_label:
					enemy_mp_labels_array.append(mp_label)
				var energy_bar = unit_node.get_node_or_null("EnemyEnergyBar%d" % (i + 1))
				if energy_bar:
					enemy_energy_bars_array.append(energy_bar)
				var energy_label = unit_node.get_node_or_null("EnemyEnergyLabel%d" % (i + 1))
				if energy_label:
					enemy_energy_labels_array.append(energy_label)

	for i in range(ally_panel_array.size()):
		var panel = ally_panel_array[i]
		if panel:
			var unit_node = panel.get_node_or_null("Ally%dUnit" % (i + 1))
			if unit_node:
				var name_label = unit_node.get_node_or_null("Ally%dName" % (i + 1))
				if name_label:
					ally_names_array.append(name_label)
				var hp_bar = unit_node.get_node_or_null("Ally%dHPBar" % (i + 1))
				if hp_bar:
					ally_hp_bars_array.append(hp_bar)
				var hp_label = unit_node.get_node_or_null("Ally%dHPLabel" % (i + 1))
				if hp_label:
					ally_hp_labels_array.append(hp_label)
				var mp_bar = unit_node.get_node_or_null("Ally%dMPBar" % (i + 1))
				if mp_bar:
					ally_mp_bars_array.append(mp_bar)
				var mp_label = unit_node.get_node_or_null("Ally%dMPLabel" % (i + 1))
				if mp_label:
					ally_mp_labels_array.append(mp_label)
				var energy_bar = unit_node.get_node_or_null("Ally%dEnergyBar" % (i + 1))
				if energy_bar:
					ally_energy_bars_array.append(energy_bar)
				var energy_label = unit_node.get_node_or_null("Ally%dEnergyLabel" % (i + 1))
				if energy_label:
					ally_energy_labels_array.append(energy_label)

	# Now assemble the UI references dictionary
	var ui_refs = {
		"enemy_sprites": enemy_sprites_array,
		"ally_sprites": ally_sprites_array,
		"enemy_names": enemy_names_array,
		"ally_names": ally_names_array,
		"enemy_hp_bars": enemy_hp_bars_array,
		"ally_hp_bars": ally_hp_bars_array,
		"enemy_hp_labels": enemy_hp_labels_array,
		"ally_hp_labels": ally_hp_labels_array,
		"enemy_mp_bars": enemy_mp_bars_array,
		"ally_mp_bars": ally_mp_bars_array,
		"enemy_mp_labels": enemy_mp_labels_array,
		"ally_mp_labels": ally_mp_labels_array,
		"enemy_energy_bars": enemy_energy_bars_array,
		"ally_energy_bars": ally_energy_bars_array,
		"enemy_energy_labels": enemy_energy_labels_array,
		"ally_energy_labels": ally_energy_labels_array,
	}

	# Initialize node_provider with both panels and UI references
	node_provider.initialize(enemy_panel_array, ally_panel_array, ui_refs)

	# Initialize Animations with references first (needed by UI manager)
	animations.initialize_references(get_animation_references())

	# Initialize UI Manager with correct method
	ui_manager.initialize_ui_references(get_ui_references())

	# Give UI manager access to combat controller (needed for target selection)
	ui_manager.combat_controller = combat_controller

	# Initialize Choreography with references
	choreography.initialize_references(get_choreography_references())

	# Initialize Turn Executor with references
	turn_executor.initialize({
		"ui_manager": ui_manager,
		"animations": animations,
		"combat_controller": combat_controller,
		"network_client": network_client,
		"floating_overlays": floating_overlays,
		"end_battle_callback": Callable(self, "end_battle")
	})

	# Initialize Result Handler with UI references
	result_handler.initialize({
		"result_popup": result_popup,
		"result_title": result_title,
		"xp_label": xp_label,
		"gold_label": gold_label,
		"action_buttons": [attack_button, defend_button, skills_button, items_button],
		"ui_manager": ui_manager
	})

	# Load sprite atlases
	BattleDataLoader.load_sprite_atlases()

func get_ui_references() -> Dictionary:
	"""Collect all UI node references for UI Manager"""
	return {
		"enemy_sprites": get_enemy_sprites(),
		"enemy_names": get_enemy_names(),
		"enemy_hp_bars": get_enemy_hp_bars(),
		"enemy_hp_labels": get_enemy_hp_labels(),
		"enemy_mp_bars": get_enemy_mp_bars(),
		"enemy_mp_labels": get_enemy_mp_labels(),
		"enemy_energy_bars": get_enemy_energy_bars(),
		"enemy_energy_labels": get_enemy_energy_labels(),
		"enemy_panels": get_enemy_panels(),

		"ally_sprites": get_ally_sprites(),
		"ally_names": get_ally_names(),
		"ally_hp_bars": get_ally_hp_bars(),
		"ally_hp_labels": get_ally_hp_labels(),
		"ally_mp_bars": get_ally_mp_bars(),
		"ally_mp_labels": get_ally_mp_labels(),
		"ally_energy_bars": get_ally_energy_bars(),
		"ally_energy_labels": get_ally_energy_labels(),
		"ally_panels": get_ally_panels(),

		"action_buttons": [attack_button, defend_button, skills_button, items_button],
		"attack_button": attack_button,
		"defend_button": defend_button,
		"skills_button": skills_button,
		"items_button": items_button,

		"turn_info": turn_info,
		"target_cursor": target_cursor
	}

func get_animation_references() -> Dictionary:
	"""Collect references for Animation system"""
	return {
		"enemy_panels": get_enemy_panels(),
		"ally_panels": get_ally_panels(),
		"enemy_sprites": get_enemy_sprites(),
		"ally_sprites": get_ally_sprites(),
		"enemy_hp_bars": get_enemy_hp_bars(),
		"ally_hp_bars": get_ally_hp_bars(),
		"parent_node": self
	}

func get_choreography_references() -> Dictionary:
	"""Collect references for Choreography system"""
	return {
		"enemy_panels": get_enemy_panels(),
		"ally_panels": get_ally_panels(),
		"all_battle_panels": get_all_battle_panels(),
		"parent_node": self
	}

## ========== NODE REFERENCE HELPERS ==========
## Delegations to BattleNodeProvider (extracted in Phase 1)

func get_enemy_panels() -> Array:
	return node_provider.get_enemy_panels()

func get_ally_panels() -> Array:
	return node_provider.get_ally_panels()

func get_all_battle_panels() -> Array:
	return node_provider.get_all_battle_panels()

func get_enemy_sprites() -> Array:
	return node_provider.get_enemy_sprites()

func get_ally_sprites() -> Array:
	return node_provider.get_ally_sprites()

func get_enemy_names() -> Array:
	return node_provider.get_enemy_names()

func get_ally_names() -> Array:
	return node_provider.get_ally_names()

func get_enemy_hp_bars() -> Array:
	return node_provider.get_enemy_hp_bars()

func get_ally_hp_bars() -> Array:
	return node_provider.get_ally_hp_bars()

func get_enemy_hp_labels() -> Array:
	return node_provider.get_enemy_hp_labels()

func get_ally_hp_labels() -> Array:
	return node_provider.get_ally_hp_labels()

func get_enemy_mp_bars() -> Array:
	return node_provider.get_enemy_mp_bars()

func get_ally_mp_bars() -> Array:
	return node_provider.get_ally_mp_bars()

func get_enemy_mp_labels() -> Array:
	return node_provider.get_enemy_mp_labels()

func get_ally_mp_labels() -> Array:
	return node_provider.get_ally_mp_labels()

func get_enemy_energy_bars() -> Array:
	return node_provider.get_enemy_energy_bars()

func get_ally_energy_bars() -> Array:
	return node_provider.get_ally_energy_bars()

func get_enemy_energy_labels() -> Array:
	return node_provider.get_enemy_energy_labels()

func get_ally_energy_labels() -> Array:
	return node_provider.get_ally_energy_labels()

## ========== SIGNAL WIRING ==========

func connect_subsystem_signals():
	"""Wire up all signal connections between subsystems"""

	# Combat Controller → UI Manager
	combat_controller.selection_phase_started.connect(_on_selection_phase_started)
	combat_controller.turn_started.connect(_on_turn_started)
	combat_controller.action_queued.connect(_on_action_queued)
	combat_controller.round_executing.connect(_on_round_executing)
	combat_controller.battle_ended.connect(_on_battle_ended)

	# UI Manager → Combat Controller
	ui_manager.action_button_pressed.connect(_on_action_button_pressed)
	ui_manager.target_confirmed.connect(_on_target_confirmed)

	# Network Client → Combat Controller
	network_client.server_result_received.connect(_on_server_result_received)
	network_client.server_error.connect(_on_server_error)

	# Input Handler signals
	input_handler.attack_requested.connect(_on_attack_pressed)
	input_handler.defend_requested.connect(_on_defend_pressed)
	input_handler.skills_requested.connect(_on_skills_pressed)
	input_handler.items_requested.connect(_on_items_pressed)
	input_handler.target_navigation.connect(_on_target_navigation)
	input_handler.target_confirmed.connect(_on_input_target_confirmed)
	input_handler.target_cancelled.connect(_on_target_cancelled)
	input_handler.continue_pressed.connect(_on_continue_button_pressed)

	# Button connections (mouse clicks still work)
	attack_button.pressed.connect(_on_attack_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	skills_button.pressed.connect(_on_skills_pressed)
	items_button.pressed.connect(_on_items_pressed)

	# Layout button connections
	save_layout_button.pressed.connect(_on_save_layout_pressed)
	reset_layout_button.pressed.connect(_on_reset_layout_pressed)
	if save_ui_button:
		save_ui_button.pressed.connect(_on_save_ui_button_pressed)

	# Result popup button connection
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)

	# Enemy panel mouse click connections (delegated to input_handler)
	enemy_panel_1.gui_input.connect(input_handler.handle_enemy_panel_click.bind(0))
	enemy_panel_2.gui_input.connect(input_handler.handle_enemy_panel_click.bind(1))
	enemy_panel_3.gui_input.connect(input_handler.handle_enemy_panel_click.bind(2))
	enemy_panel_4.gui_input.connect(input_handler.handle_enemy_panel_click.bind(3))
	enemy_panel_5.gui_input.connect(input_handler.handle_enemy_panel_click.bind(4))
	enemy_panel_6.gui_input.connect(input_handler.handle_enemy_panel_click.bind(5))

## ========== BATTLE SETUP ==========

func setup_battle():
	"""Setup battle from server or local data"""

	# Check for server battle
	var server_data = BattleNetworkClient.load_server_combat_data()

	if not server_data.is_empty():
		setup_server_battle(server_data)
	else:
		setup_local_battle()

func setup_server_battle(server_data: Dictionary):
	"""Setup server-controlled battle"""
	var combat_id = server_data.get("combat_id", -1)
	var player_initiated = server_data.get("player_initiated", true)

	# Initialize network client
	network_client.initialize_server_battle(combat_id)

	# Load squads
	player_character = BattleDataLoader.load_player_character()
	enemy_squad = BattleDataLoader.load_server_enemy_squad(server_data.get("enemy_squad", []))
	ally_squad = BattleDataLoader.load_server_ally_squad()  # Use server team NPCs

	# Initialize combat controller
	combat_controller.initialize_battle(enemy_squad, ally_squad, player_character, true, combat_id)
	combat_controller.set_battle_initiator(player_initiated)

	# Set squad references in UI manager, turn executor, and result handler
	ui_manager.set_squad_references(enemy_squad, ally_squad)
	turn_executor.set_squads(enemy_squad, ally_squad, player_character)
	result_handler.set_enemy_squad(enemy_squad)

	# Update all UI
	ui_manager.update_all_enemies_ui()
	ui_manager.update_all_allies_ui()

	# Hide large HP/MP bars (we only want small floating ones)
	floating_overlays.hide_large_hp_bars(get_enemy_panels, get_ally_panels)

	# Re-hide title bars (in case panels were recreated)
	floating_overlays.hide_panel_title_bars(get_enemy_panels, get_ally_panels)
	floating_overlays.hide_name_labels(get_enemy_names, get_ally_names)

	# Calculate turn order
	combat_controller.calculate_turn_order()

	# Start selection phase
	combat_controller.start_selection_phase()

	# Initialize and update floating overlays (NOW that squads are loaded)
	floating_overlays.initialize(ui_manager, enemy_squad, ally_squad)
	floating_overlays.update_overlays()

func setup_local_battle():
	"""Setup local (non-server) battle"""
	# Initialize network client as local
	network_client.initialize_local_battle()

	# Load squads
	player_character = BattleDataLoader.load_player_character()
	enemy_squad = BattleDataLoader.load_enemy_squad()
	ally_squad = BattleDataLoader.load_ally_squad()

	# Initialize combat controller
	combat_controller.initialize_battle(enemy_squad, ally_squad, player_character, false, -1)
	combat_controller.set_battle_initiator(true)  # Player initiated local battle

	# Set squad references in UI manager, turn executor, and result handler
	ui_manager.set_squad_references(enemy_squad, ally_squad)
	turn_executor.set_squads(enemy_squad, ally_squad, player_character)
	result_handler.set_enemy_squad(enemy_squad)

	# Update all UI
	ui_manager.update_all_enemies_ui()
	ui_manager.update_all_allies_ui()

	# Hide large HP/MP bars (we only want small floating ones)
	floating_overlays.hide_large_hp_bars(get_enemy_panels, get_ally_panels)

	# Re-hide title bars (in case panels were recreated)
	floating_overlays.hide_panel_title_bars(get_enemy_panels, get_ally_panels)
	floating_overlays.hide_name_labels(get_enemy_names, get_ally_names)

	# Calculate turn order
	combat_controller.calculate_turn_order()

	# Start selection phase
	combat_controller.start_selection_phase()

	# Initialize and update floating overlays (NOW that squads are loaded)
	floating_overlays.initialize(ui_manager, enemy_squad, ally_squad)
	floating_overlays.update_overlays()

## ========== SIGNAL HANDLERS ==========

func _on_selection_phase_started(round: int):
	"""Combat controller started selection phase"""
	ui_manager.enable_action_buttons()
	ui_manager.update_turn_info("Choose your action!")

func _on_turn_started(unit_type: String, unit_data: Dictionary, _unit_index: int):
	"""Combat controller started a unit's turn - delegate to turn_executor"""
	var unit_name = unit_data.get("character_name", "Unknown")
	ui_manager.update_turn_info("%s's turn!" % unit_name)

	# Delegate turn execution to turn_executor
	if unit_type == "player":
		turn_executor.execute_player_turn()
	elif unit_type == "ally":
		turn_executor.execute_ally_turn(unit_data)
	else:
		turn_executor.execute_enemy_turn(unit_data)

func _on_action_queued(action: String, target_id: int):
	"""Combat controller queued an action"""
	# NOTE: Do NOT send to server here!
	# execute_player_attack() handles server communication with proper response waiting.
	# Sending here would cause duplicate sends and race conditions where the response
	# arrives before execute_player_attack() connects its signal handler.

func _on_round_executing():
	"""Combat controller started executing round"""
	ui_manager.disable_action_buttons()

func _on_battle_ended(victory: bool):
	"""Combat controller ended battle"""
	if victory:
		ui_manager.update_turn_info("Victory! All enemies defeated!")
	else:
		ui_manager.update_turn_info("Defeat... All allies defeated.")

	# Send battle end to server if needed
	network_client.send_battle_end(victory)

func _on_action_button_pressed(_action: String):
	"""UI manager reported action button press"""
	pass

func _on_target_confirmed(target_index: int):
	"""UI manager confirmed target selection"""
	combat_controller.queue_player_action("attack", target_index)

func _on_server_result_received(_results: Dictionary):
	"""Network client received server results"""
	# Process server results (update HP, etc.)
	pass

func _on_server_error(error_message: String):
	"""Network client reported error"""
	ui_manager.update_turn_info("Server error: " + error_message)

## ========== BUTTON HANDLERS ==========

func _on_attack_pressed():
	"""Player clicked Attack button"""
	ui_manager.start_target_selection()

func _on_defend_pressed():
	"""Player clicked Defend button"""
	combat_controller.queue_player_action("defend", -1)

func _on_skills_pressed():
	"""Player clicked Skills button - not yet implemented"""
	pass

func _on_items_pressed():
	"""Player clicked Items button - not yet implemented"""
	pass

func _on_save_layout_pressed():
	"""Player clicked Save Layout button"""
	save_ui_layout()

func _on_reset_layout_pressed():
	"""Player clicked Reset Layout button"""
	choreography.reset_battle_layout()
	load_ui_layout()  # Reload default layout

func _on_save_ui_button_pressed():
	"""Player clicked Save UI button (top-right corner icon)"""
	save_ui_layout()

## ========== INPUT HANDLER SIGNALS ==========
## Input handling delegated to BattleInputHandler

func _on_target_navigation(direction: String):
	"""Input handler requested target navigation"""
	ui_manager.navigate_target_direction(direction)

func _on_input_target_confirmed():
	"""Input handler confirmed target selection"""
	ui_manager.confirm_target_selection()

func _on_target_cancelled():
	"""Input handler cancelled target selection"""
	ui_manager.cancel_target_selection()

## ========== PROCESS ==========

func _process(delta: float):
	"""Update battle state each frame"""
	# Process selection phase timer
	if combat_controller:
		combat_controller.process_selection_phase(delta)

		# Update selection phase display
		var timer = combat_controller.get_selection_timer()
		var action_confirmed = combat_controller.get_player_queued_action().get("confirmed", false)
		ui_manager.update_selection_phase_display(timer, action_confirmed)

	# Update floating overlay positions every frame
	if floating_overlays:
		floating_overlays.update_positions()

## ========== SERVER RESULT HANDLING ==========

func receive_round_results(results: Dictionary):
	"""Called by multiplayer_manager when server sends combat_round_results RPC.
	Forwards to network_client to emit signal that execute_player_attack() awaits."""
	if network_client:
		# Forward to network_client which will emit action_result_received signal
		network_client.receive_action_result(results)

## ========== UI LAYOUT SAVE/LOAD SYSTEM ==========
## Delegated to BattleLayoutManager

func save_ui_layout():
	"""Save all panel positions and sizes to user:// directory"""
	BattleLayoutManager.save_layout(get_enemy_panels(), get_ally_panels(), ui_panel)

func load_ui_layout():
	"""Load panel positions and sizes from user:// directory"""
	BattleLayoutManager.load_layout(get_enemy_panels(), get_ally_panels(), ui_panel)

## ========== DAMAGE CALCULATION SYSTEM ==========
## Delegations to BattleDamageCalculator (extracted in Phase 2)

func is_front_row(panel_index: int, is_enemy: bool) -> bool:
	"""Wrapper for BattleDamageCalculator.is_front_row()"""
	return BattleDamageCalculator.is_front_row(panel_index, is_enemy)

func get_character_attack_type(character_data: Dictionary) -> String:
	"""Wrapper for BattleDamageCalculator.get_character_attack_type()"""
	return BattleDamageCalculator.get_character_attack_type(character_data)

func calculate_range_penalty(attacker_data: Dictionary, attacker_index: int, defender_index: int, is_attacker_enemy: bool, is_defender_enemy: bool) -> float:
	"""Wrapper for BattleDamageCalculator.calculate_range_penalty()"""
	return BattleDamageCalculator.calculate_range_penalty(attacker_data, attacker_index, defender_index, is_attacker_enemy, is_defender_enemy)

func get_defensive_modifier(combat_role: String) -> float:
	"""Wrapper for BattleDamageCalculator.get_defensive_modifier()"""
	return BattleDamageCalculator.get_defensive_modifier(combat_role)

func calculate_damage(attacker: Dictionary, defender: Dictionary, attacker_index: int = -1, defender_index: int = -1, is_attacker_enemy: bool = false) -> int:
	"""Wrapper for BattleDamageCalculator.calculate_damage()"""
	return BattleDamageCalculator.calculate_damage(attacker, defender, attacker_index, defender_index, is_attacker_enemy)

func calculate_basic_damage(attacker: Dictionary, defender: Dictionary) -> int:
	"""Wrapper for BattleDamageCalculator.calculate_basic_damage()"""
	return BattleDamageCalculator.calculate_basic_damage(attacker, defender)

## ========== BATTLE END ==========
## Delegated to BattleResultHandler

func end_battle(victory: bool):
	"""End battle - delegate to result handler"""
	result_handler.show_result(victory)

func _on_continue_button_pressed():
	"""Return to dev client - delegate to result handler"""
	result_handler.on_continue_pressed()
