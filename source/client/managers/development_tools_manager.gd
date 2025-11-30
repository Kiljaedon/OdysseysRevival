class_name DevelopmentToolsManager
extends Node

## Phase 3: Development Tools Manager - Handles external tools and character data loading
## Manages: Sprite creator, map editor, art studio, character class loading

## Game references (dependency injection)
var character_sprite_manager: Node  # For loading character data
var map_manager: Node  # For map operations

## Character data
var character_classes: Array[String] = []
var available_maps: Array[String] = []
var maps_directory: String = "res://maps/"

## ============================================================================
## INITIALIZATION
## ============================================================================

func initialize(char_mgr: Node, map_mgr: Node = null) -> void:
	"""Initialize development tools manager with dependencies.

	Args:
		char_mgr: CharacterSpriteManager for character data loading
		map_mgr: Optional MapManager for map operations
	"""
	character_sprite_manager = char_mgr
	map_manager = map_mgr

	print("[DevelopmentToolsManager] Initialized with dependencies")

## ============================================================================
## EXTERNAL TOOL LAUNCHERS
## ============================================================================

func _on_sprite_creator_pressed() -> void:
	"""Launch sprite creator tool.

	Transitions to odyssey_sprite_maker scene where users can create
	and edit character sprite animations.
	"""
	# Check admin privileges
	if GameState.admin_level < 1:
		print("[DevTools] Access denied to Sprite Creator: Admin required")
		_show_access_denied("Sprite Creator")
		return

	print("[DevTools] Launching Sprite Creator...")
	get_tree().change_scene_to_file("res://odyssey_sprite_maker.tscn")

func _on_map_editor_pressed() -> void:
	"""Launch Tiled map editor.

	Launches portable Tiled application with the Golden Sun MMO project.
	Falls back to message if Tiled is not found.
	"""
	# Check admin privileges
	if GameState.admin_level < 1:
		print("[DevTools] Access denied to Map Editor: Admin required")
		_show_access_denied("Map Editor")
		return

	print("[DevTools] Launching Map Editor (Tiled)...")
	var tiled_project_path = ProjectSettings.globalize_path("res://tiled_projects/golden_sun_mmo.tiled-project")
	var portable_tiled = ProjectSettings.globalize_path("res://tools/tiled/tiled.exe")

	if FileAccess.file_exists(portable_tiled):
		OS.create_process(portable_tiled, [tiled_project_path])
		print("[DevTools] ✓ Tiled launched successfully")
	else:
		print("[DevTools] ⚠️  Tiled not found at: ", portable_tiled)
		print("[DevTools] Implement fallback map editor or install Tiled")

func _on_art_studio_pressed() -> void:
	"""Launch PixiEditor for sprite art editing.

	Launches PixiEditor with the Odyssey sprites file for editing
	pixel art directly.
	"""
	print("[DevTools] Launching Art Studio (PixiEditor)...")
	var portable_pixieditor = ProjectSettings.globalize_path("res://tools/pixieditor/PixiEditor/PixiEditor.exe")
	var sprites_file = ProjectSettings.globalize_path("res://assets-odyssey/sprites.png")

	if FileAccess.file_exists(portable_pixieditor):
		OS.create_process(portable_pixieditor, [sprites_file])
		print("[DevTools] ✓ PixiEditor launched successfully")
	else:
		print("[DevTools] ⚠️  PixiEditor not found at: ", portable_pixieditor)

## ============================================================================
## CHARACTER CLASS LOADING
## ============================================================================

func load_character_classes() -> void:
	"""Load available character classes and NPCs from character directories.

	Populates character_classes array with:
	- [CLASS] classes from res://characters/classes/
	- [NPC] NPCs from res://characters/npcs/

	Signal: classes_loaded(character_classes)
	"""
	print("[DevTools] Loading character classes and NPCs...")
	character_classes.clear()

	# Load classes from characters/classes/
	var classes_dir = DirAccess.open("res://characters/classes/")
	if classes_dir:
		classes_dir.list_dir_begin()
		var file_name = classes_dir.get_next()

		while file_name != "":
			if file_name.ends_with(".json"):
				var character_name = file_name.get_basename()
				character_classes.append("class:" + character_name)
				print("[DevTools] Found class: ", character_name)
			file_name = classes_dir.get_next()
		classes_dir.list_dir_end()

	# Load NPCs from characters/npcs/
	var npcs_dir = DirAccess.open("res://characters/npcs/")
	if npcs_dir:
		npcs_dir.list_dir_begin()
		var file_name = npcs_dir.get_next()

		while file_name != "":
			if file_name.ends_with(".json"):
				var character_name = file_name.get_basename()
				character_classes.append("npc:" + character_name)
				print("[DevTools] Found NPC: ", character_name)
			file_name = npcs_dir.get_next()
		npcs_dir.list_dir_end()

	print("[DevTools] ✓ Loaded %d character classes/NPCs" % character_classes.size())
	classes_loaded.emit(character_classes)

func _on_class_selected(index: int, class_dropdown: OptionButton) -> void:
	"""Signal handler when user selects a character class.

	Args:
		index: Selected dropdown index
		class_dropdown: The OptionButton control
	"""
	if index < character_classes.size():
		var selected_class = character_classes[index]
		print("[DevTools] Character selected: ", selected_class)
		character_class_changed.emit(selected_class)

		# Load character data through sprite manager
		if character_sprite_manager and character_sprite_manager.has_method("load_character_data"):
			var character_name = selected_class.split(":")[1] if ":" in selected_class else selected_class
			character_sprite_manager.load_character_data(character_name)

## ============================================================================
## MAP LOADING
## ============================================================================

func load_maps() -> void:
	"""Scan and load available TMX maps from res://maps/ directory.

	Populates available_maps array with filenames.
	Signal: maps_loaded(available_maps)
	"""
	print("[DevTools] Scanning for available maps...")

	available_maps.clear()

	# Scan for TMX files
	var maps_dir = DirAccess.open(maps_directory)
	if maps_dir:
		maps_dir.list_dir_begin()
		var file_name = maps_dir.get_next()

		while file_name != "":
			if file_name.ends_with(".tmx"):
				var map_name = file_name.get_basename()
				available_maps.append(map_name)
				print("[DevTools] Found map: ", map_name)
			file_name = maps_dir.get_next()
		maps_dir.list_dir_end()

	# Add default test map option
	available_maps.append("default_test")

	print("[DevTools] ✓ Loaded %d maps" % available_maps.size())
	maps_loaded.emit(available_maps)

func _on_load_map_pressed(map_dropdown: OptionButton) -> void:
	"""Signal handler for loading selected map.

	Args:
		map_dropdown: The OptionButton containing map selection
	"""
	print("[DevTools] Load map button pressed")
	print("[DevTools] Dropdown selected index: ", map_dropdown.selected)
	print("[DevTools] Available maps: ", available_maps)

	var selected_index = map_dropdown.selected
	if selected_index < available_maps.size():
		var map_name = available_maps[selected_index]
		print("[DevTools] Loading map: ", map_name)
		map_selected.emit(map_name)
	else:
		print("[DevTools] ERROR: Invalid map index ", selected_index)

## ============================================================================
## NAVIGATION
## ============================================================================

func return_to_main_menu() -> void:
	"""Navigate back to main menu.

	Saves UI layout, closes server connection if needed, and transitions
	to login screen.
	"""
	print("[DevTools] Returning to main menu...")

	# Store logout timestamp for client-side cooldown display
	var game_state = get_node_or_null("/root/GameState")
	if game_state:
		game_state.set("last_logout_time", Time.get_ticks_msec() / 1000.0)

		# Close connection (server will detect disconnect and clean up)
		var client = game_state.get("client")
		if client:
			print("[DevTools] Closing server connection...")
			client.close_connection()

	get_tree().change_scene_to_file("res://source/client/ui/login_screen.tscn")

## ============================================================================
## ADMIN ACCESS CONTROL
## ============================================================================

func _show_access_denied(tool_name: String) -> void:
	"""Display access denied message for admin-only tools.

	Args:
		tool_name: Name of the tool that was blocked (e.g. "Sprite Creator")
	"""
	print("[DevTools] Access denied to %s: Admin privileges required" % tool_name)
	# Note: Can be enhanced with visual popup if needed
	# For now, just logging. UI screens (sprite maker, etc) have their own error displays

## ============================================================================
## SIGNALS (for UI controller communication)
## ============================================================================

signal classes_loaded(classes: Array[String])
signal character_class_changed(class_identifier: String)
signal maps_loaded(maps: Array[String])
signal map_selected(map_name: String)
