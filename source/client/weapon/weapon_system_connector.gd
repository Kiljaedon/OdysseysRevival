class_name WeaponSystemConnector
extends Node
## Weapon System Connector
## Auto-discovers and connects weapon system components
## - Finds TestCharacter in scene
## - Finds WeaponState component on TestCharacter
## - Finds WeaponEmoteDisplay in DevUI
## - Finds WeaponSheathIndicator on TestCharacter
## - Initializes weapon sheath indicator with player name
## - Connects weapon state signals to emote display automatically
##
## Usage: Add as child node to dev_client scene (NO code modifications needed)

# Discovered components
var test_character: CharacterBody2D = null
var weapon_state: WeaponState = null
var emote_display: Control = null
var sheath_indicator: Control = null
var input_handler_manager: Node = null


func _ready() -> void:
	# Wait one frame for scene to fully initialize
	await get_tree().process_frame

	# Auto-discover components
	_discover_components()

	# Connect if weapon_state and emote_display found
	if weapon_state and emote_display:
		_connect_signals()

	# Setup weapon sheath indicator
	if weapon_state and sheath_indicator:
		_setup_sheath_indicator()

	# CRITICAL: Setup input handler manager weapon state reference (must work even without emote_display)
	if weapon_state and input_handler_manager:
		input_handler_manager.weapon_state = weapon_state
		print("[WeaponSystemConnector] Connected weapon_state to InputHandlerManager - ATTACKS ENABLED")

	# Log any missing components
	if not test_character or not weapon_state or not emote_display or not sheath_indicator:
		_log_missing_components()


func _discover_components() -> void:
	"""Auto-discover weapon system components in the scene"""

	# Find TestCharacter in GameWorld
	var game_world = get_tree().root.find_child("GameWorld", true, false)
	if game_world:
		test_character = game_world.get_node_or_null("TestCharacter")

	# Find WeaponState component on TestCharacter
	if test_character:
		weapon_state = test_character.get_node_or_null("WeaponState")

	# Find WeaponSheathIndicator on TestCharacter
	if test_character:
		sheath_indicator = test_character.get_node_or_null("WeaponSheathIndicator")

	# Find InputHandlerManager on DevClient (it's created programmatically there)
	var dev_client = get_tree().root.find_child("DevClient", true, false)
	if dev_client:
		input_handler_manager = dev_client.get_node_or_null("InputHandlerManager")

	# Find WeaponEmoteDisplay in DevUI
	var dev_ui = get_tree().root.find_child("DevUI", true, false)
	if dev_ui:
		emote_display = dev_ui.get_node_or_null("WeaponEmoteDisplay")


func _connect_signals() -> void:
	"""Connect WeaponState signals to WeaponEmoteDisplay"""

	# Connect weapon toggle signals
	weapon_state.weapon_unsheathed.connect(_on_weapon_readied)
	weapon_state.weapon_sheathed.connect(_on_weapon_sheathed)
	weapon_state.state_changed.connect(_on_state_changed)

	print("[WeaponSystemConnector] Successfully connected weapon emote feedback")


func _setup_sheath_indicator() -> void:
	"""Initialize the weapon sheath indicator with weapon state"""

	# Initialize the weapon sheath indicator
	if sheath_indicator.has_method("setup"):
		sheath_indicator.setup(weapon_state)
		print("[WeaponSystemConnector] WeaponSheathIndicator initialized")
	else:
		push_warning("[WeaponSystemConnector] WeaponSheathIndicator missing setup() method")


func _log_missing_components() -> void:
	"""Log which components are missing"""
	if not test_character:
		push_warning("[WeaponSystemConnector] TestCharacter not found in GameWorld")

	if not weapon_state:
		push_warning("[WeaponSystemConnector] WeaponState not found on TestCharacter")

	if not emote_display:
		push_warning("[WeaponSystemConnector] WeaponEmoteDisplay not found in DevUI")

	if not sheath_indicator:
		push_warning("[WeaponSystemConnector] WeaponSheathIndicator not found on TestCharacter")


## Signal Handlers

func _on_weapon_readied() -> void:
	"""Called when player readies their weapon"""
	if emote_display and emote_display.has_method("show_weapon_ready"):
		emote_display.show_weapon_ready()


func _on_weapon_sheathed() -> void:
	"""Called when player sheathes their weapon"""
	if emote_display and emote_display.has_method("show_weapon_sheathed"):
		emote_display.show_weapon_sheathed()


func _on_state_changed(is_sheathed: bool) -> void:
	"""Log weapon state changes for debugging"""
	var state_text = "SHEATHED (safe)" if is_sheathed else "UNSHEATHED (combat ready)"
	print("[WeaponSystemConnector] Weapon state changed to: %s" % state_text)
