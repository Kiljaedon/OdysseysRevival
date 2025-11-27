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

# Action button navigation
var action_buttons: Array = []
var selected_button_index: int = 0

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

	# Initialize action buttons array for keyboard navigation
	action_buttons = [attack_button, defend_button, skills_button, items_button]
	selected_button_index = 0
	update_button_selection()  # Highlight first button

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

	# Add as children
	add_child(combat_controller)
	add_child(ui_manager)
	add_child(animations)
	add_child(network_client)
	add_child(choreography)
	add_child(node_provider)
	add_child(floating_overlays)

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

	# Button connections
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

	# Enemy panel mouse click connections
	enemy_panel_1.gui_input.connect(_on_enemy_panel_clicked.bind(0))
	enemy_panel_2.gui_input.connect(_on_enemy_panel_clicked.bind(1))
	enemy_panel_3.gui_input.connect(_on_enemy_panel_clicked.bind(2))
	enemy_panel_4.gui_input.connect(_on_enemy_panel_clicked.bind(3))
	enemy_panel_5.gui_input.connect(_on_enemy_panel_clicked.bind(4))
	enemy_panel_6.gui_input.connect(_on_enemy_panel_clicked.bind(5))

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

	# Set squad references in UI manager
	ui_manager.set_squad_references(enemy_squad, ally_squad)

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

	# Set squad references in UI manager
	ui_manager.set_squad_references(enemy_squad, ally_squad)

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

func _on_turn_started(unit_type: String, unit_data: Dictionary, unit_index: int):
	"""Combat controller started a unit's turn"""
	var unit_name = unit_data.get("character_name", "Unknown")
	ui_manager.update_turn_info("%s's turn!" % unit_name)

	# Execute the turn based on unit type
	if unit_type == "player":
		execute_player_turn()
	elif unit_type == "ally":
		execute_ally_turn(unit_data)
	else:
		execute_enemy_turn(unit_data)

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

func _on_enemy_panel_clicked(event: InputEvent, enemy_index: int):
	"""Handle mouse clicks on enemy panels during target selection"""
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return

	# Only process during TARGET_SELECTION state
	var battle_state = combat_controller.get_battle_state() if combat_controller else -1
	if battle_state != 1:  # 1 = TARGET_SELECTION
		return

	# Check if enemy is alive
	var enemy_squad = combat_controller.get_enemy_squad() if combat_controller else []
	if enemy_index >= enemy_squad.size():
		return
	if enemy_squad[enemy_index].get("hp", 0) <= 0:
		return

	# Select and auto-confirm target
	ui_manager.selected_target_index = enemy_index
	ui_manager.show_target_cursor(enemy_index)
	ui_manager.confirm_target_selection()  # Auto-confirm on click

## ========== INPUT HANDLING ==========

func _input(event: InputEvent):
	"""Handle keyboard input for battle"""
	if not event is InputEventKey or not event.pressed:
		return

	# BLOCK ESCAPE KEY - Don't allow exiting battle mid-fight
	if event.keycode == KEY_ESCAPE:
		# Only allow Escape to cancel target selection
		var battle_state = combat_controller.get_battle_state() if combat_controller else -1
		if battle_state == 1:  # TARGET_SELECTION - allow cancel
			ui_manager.cancel_target_selection()
		# Block Escape during all other battle phases
		get_viewport().set_input_as_handled()
		return

	# Allow SPACE to close victory/defeat popup
	if event.keycode == KEY_SPACE:
		if result_popup and result_popup.visible:
			get_viewport().set_input_as_handled()
			_on_continue_button_pressed()
			return

	# Get battle state from combat controller
	var battle_state = combat_controller.get_battle_state() if combat_controller else -1

	# SELECTION_PHASE: Navigate action buttons (Attack/Defend/Skills/Items)
	if battle_state == 0:  # SELECTION_PHASE state
		match event.keycode:
			KEY_W, KEY_UP, KEY_A, KEY_LEFT:
				# Cycle to previous button
				selected_button_index = (selected_button_index - 1 + action_buttons.size()) % action_buttons.size()
				update_button_selection()
				get_viewport().set_input_as_handled()
			KEY_S, KEY_DOWN, KEY_D, KEY_RIGHT:
				# Cycle to next button
				selected_button_index = (selected_button_index + 1) % action_buttons.size()
				update_button_selection()
				get_viewport().set_input_as_handled()
			KEY_SPACE, KEY_ENTER:
				# Activate selected button
				if selected_button_index < action_buttons.size() and action_buttons[selected_button_index]:
					if not action_buttons[selected_button_index].disabled:
						action_buttons[selected_button_index].emit_signal("pressed")
						get_viewport().set_input_as_handled()
			KEY_1:
				if attack_button and not attack_button.disabled:
					_on_attack_pressed()
					get_viewport().set_input_as_handled()
			KEY_2:
				if defend_button and not defend_button.disabled:
					_on_defend_pressed()
					get_viewport().set_input_as_handled()
			KEY_3:
				if skills_button and not skills_button.disabled:
					_on_skills_pressed()
					get_viewport().set_input_as_handled()
			KEY_4:
				if items_button and not items_button.disabled:
					_on_items_pressed()
					get_viewport().set_input_as_handled()

	# TARGET_SELECTION: Navigate enemy targets
	elif battle_state == 1:  # TARGET_SELECTION state
		match event.keycode:
			KEY_W, KEY_UP:
				ui_manager.navigate_target_direction("up")
				get_viewport().set_input_as_handled()
			KEY_S, KEY_DOWN:
				ui_manager.navigate_target_direction("down")
				get_viewport().set_input_as_handled()
			KEY_A, KEY_LEFT:
				ui_manager.navigate_target_direction("left")
				get_viewport().set_input_as_handled()
			KEY_D, KEY_RIGHT:
				ui_manager.navigate_target_direction("right")
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				ui_manager.confirm_target_selection()
				get_viewport().set_input_as_handled()
		return  # IMPORTANT: Prevent other input processing

func update_button_selection():
	"""Update visual feedback for selected action button"""
	for i in range(action_buttons.size()):
		if action_buttons[i]:
			if i == selected_button_index:
				action_buttons[i].grab_focus()
				# Yellow highlight for selected button
				action_buttons[i].modulate = Color(1.5, 1.5, 0.5)
			else:
				action_buttons[i].release_focus()
				# Normal color
				action_buttons[i].modulate = Color(1, 1, 1)

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

## ========== TURN EXECUTION ==========

func execute_player_turn():
	"""Execute player's queued action"""
	var queued = combat_controller.get_player_queued_action()
	var action = queued.get("action", "defend")
	var target_id = queued.get("target_id", -1)

	if action == "attack" and target_id >= 0:
		execute_player_attack(target_id)
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
	if combat_controller.is_server_battle and network_client:
		network_client.send_player_action("attack", target_index)
		# Response handled by _on_server_result_received via signal
	else:
		# LOCAL BATTLE: Client-side calculation
		var damage = calculate_damage(player_character, target, 0, target_index, false)
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
		end_battle(battle_end.victory)
		return

	await get_tree().create_timer(1.5).timeout
	combat_controller.advance_turn()

func execute_ally_turn(ally_data: Dictionary):
	"""Execute ally NPC's turn (AI)"""
	var ally_name = ally_data.get("character_name", "Unknown")

	# SHOW whose turn it is
	ui_manager.update_turn_info("⚔️ %s's turn!" % ally_name)
	await get_tree().create_timer(0.5).timeout  # Pause so user can see whose turn it is

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
	# ally_index is attacker position, is_attacker_enemy = false
	var damage = calculate_damage(ally_data, target, ally_index, target_index, false)

	target.hp -= damage
	target.hp = max(0, target.hp)

	var target_name = target.get("character_name", "Enemy")
	ui_manager.update_turn_info("⚔️ %s attacks %s for %d damage!" % [ally_name, target_name, damage])
	ui_manager.update_enemy_ui(target_index)
	floating_overlays.update_overlays()  # Update floating HP bars

	# Check if target defeated
	if target.hp <= 0:
		# Hide defeated enemy panel
		var enemy_panels = ui_manager.get_enemy_panels() if ui_manager else []
		if target_index < enemy_panels.size() and enemy_panels[target_index]:
			enemy_panels[target_index].visible = false
		# Hide defeated enemy overlay
		floating_overlays.hide_overlay(true, target_index)

	# Check battle end
	var battle_end = combat_controller.check_battle_end()
	if battle_end.ended:
		end_battle(battle_end.victory)
		return

	await get_tree().create_timer(1.5).timeout
	combat_controller.advance_turn()

func execute_enemy_turn(enemy_data: Dictionary):
	"""Execute enemy's turn (AI)"""
	var enemy_name = enemy_data.get("character_name", "Unknown")

	# SHOW whose turn it is
	ui_manager.update_turn_info("💀 %s's turn!" % enemy_name)
	await get_tree().create_timer(0.5).timeout  # Pause so user can see whose turn it is

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
	# enemy_index is attacker position, player_index is defender, is_attacker_enemy = true
	var damage = calculate_damage(enemy_data, ally_squad[player_index], enemy_index, player_index, true)

	ally_squad[player_index].hp -= damage
	ally_squad[player_index].hp = max(0, ally_squad[player_index].hp)

	ui_manager.update_turn_info("💀 %s attacks %s for %d damage!" % [enemy_name, player_name, damage])
	ui_manager.update_ally_ui(player_index)
	floating_overlays.update_overlays()  # Update floating HP bars

	# Check if player defeated
	if ally_squad[player_index].hp <= 0:
		# Hide defeated ally panel
		var ally_panels = ui_manager.get_ally_panels() if ui_manager else []
		if player_index < ally_panels.size() and ally_panels[player_index]:
			ally_panels[player_index].visible = false
		# Hide defeated ally overlay
		floating_overlays.hide_overlay(false, player_index)

	# Check battle end
	var battle_end = combat_controller.check_battle_end()
	if battle_end.ended:
		end_battle(battle_end.victory)
		return

	await get_tree().create_timer(1.5).timeout
	combat_controller.advance_turn()


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

## ========== FLOATING HP BAR OVERLAYS ==========

## ========== BATTLE END ==========

func end_battle(victory: bool):
	"""End battle with victory or defeat"""
	# Disable all buttons
	if attack_button:
		attack_button.disabled = true
	if defend_button:
		defend_button.disabled = true
	if skills_button:
		skills_button.disabled = true
	if items_button:
		items_button.disabled = true

	if victory:
		ui_manager.update_turn_info("VICTORY! You defeated all enemies!")

		# Calculate rewards
		var rewards = calculate_rewards()

		# Update popup text
		if result_title:
			result_title.text = "VICTORY!"
			result_title.modulate = Color(0.2, 1.0, 0.2)  # Green
		if xp_label:
			xp_label.text = "XP Gained: " + str(rewards.xp)
		if gold_label:
			gold_label.text = "Gold Earned: " + str(rewards.gold)

		# Show popup
		if result_popup:
			result_popup.visible = true
	else:
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

func _on_continue_button_pressed():
	"""Return to dev client when continue button is pressed"""
	if result_popup:
		result_popup.visible = false

	# Clear battle flag in GameState
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		game_state.set_meta("in_server_battle", false)

	# Return to dev_client scene (position will be automatically restored by map_manager)
	get_tree().change_scene_to_file("res://dev_client.tscn")
