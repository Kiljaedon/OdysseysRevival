class_name BattleChoreography
extends Node
## Battle Choreography System - Handles panel positioning, layout save/load, screenshots
## Extracted from battle_window.gd for modularity

# Signals
signal layout_saved(save_number: int)
signal layout_loaded(save_number: int)
signal layout_reset()

# Panel references (set by battle_window_v2)
var enemy_panels: Array = []
var ally_panels: Array = []
var all_battle_panels: Array = []

# Parent node for viewport capture
var parent_node: Node = null

# Layout constants - Perfect grid alignment
const ENEMY_BACK_X = 65.0
const ENEMY_FRONT_X = 265.0
const ALLY_FRONT_X = 165.0
const ALLY_BACK_X = 365.0
const ROW_1_Y = 150.0  # Moved down from 90.0
const ROW_2_Y = 310.0  # Moved down from 250.0
const ROW_3_Y = 470.0  # Moved down from 410.0
const PANEL_WIDTH = 170.0
const ENEMY_HEIGHT = 290.0
const ALLY_HEIGHT = 320.0

## ========== INITIALIZATION ==========

func initialize_references(refs: Dictionary):
	"""Set all panel references from parent scene"""
	enemy_panels = refs.get("enemy_panels", [])
	ally_panels = refs.get("ally_panels", [])
	all_battle_panels = refs.get("all_battle_panels", [])
	parent_node = refs.get("parent_node", null)

## ========== PANEL ALIGNMENT ==========

func auto_align_all_panels():
	"""Force all panels into perfect grid alignment"""
	print("🔲 Auto-aligning all panels to grid...")

	# Enemy Front Row (panels 0, 1, 2)
	if enemy_panels.size() >= 3:
		enemy_panels[0].position = Vector2(ENEMY_FRONT_X, ROW_1_Y)
		enemy_panels[0].size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

		enemy_panels[1].position = Vector2(ENEMY_FRONT_X, ROW_2_Y)
		enemy_panels[1].size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

		enemy_panels[2].position = Vector2(ENEMY_FRONT_X, ROW_3_Y)
		enemy_panels[2].size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	# Enemy Back Row (panels 3, 4, 5)
	if enemy_panels.size() >= 6:
		enemy_panels[3].position = Vector2(ENEMY_BACK_X, ROW_1_Y)
		enemy_panels[3].size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

		enemy_panels[4].position = Vector2(ENEMY_BACK_X, ROW_2_Y)
		enemy_panels[4].size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

		enemy_panels[5].position = Vector2(ENEMY_BACK_X, ROW_3_Y)
		enemy_panels[5].size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	# Ally Front Row (panels 0, 1, 2)
	if ally_panels.size() >= 3:
		ally_panels[0].position = Vector2(ALLY_FRONT_X, ROW_1_Y)
		ally_panels[0].size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

		ally_panels[1].position = Vector2(ALLY_FRONT_X, ROW_2_Y)
		ally_panels[1].size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

		ally_panels[2].position = Vector2(ALLY_FRONT_X, ROW_3_Y)
		ally_panels[2].size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

	# Ally Back Row (panels 3, 4, 5)
	if ally_panels.size() >= 6:
		ally_panels[3].position = Vector2(ALLY_BACK_X, ROW_1_Y)
		ally_panels[3].size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

		ally_panels[4].position = Vector2(ALLY_BACK_X, ROW_2_Y)
		ally_panels[4].size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

		ally_panels[5].position = Vector2(ALLY_BACK_X, ROW_3_Y)
		ally_panels[5].size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

	print("✓ Panels aligned to perfect grid")
	layout_reset.emit()

func enforce_panel_alignment():
	"""Silently enforce perfect alignment every frame to prevent drift"""
	# Disable dragging/resizing on all panels
	for panel in all_battle_panels:
		if panel and "is_dragging" in panel:
			panel.is_dragging = false
		if panel and "is_resizing" in panel:
			panel.is_resizing = false

	# Enforce exact positions
	if enemy_panels.size() >= 6:
		enemy_panels[0].position = Vector2(ENEMY_FRONT_X, ROW_1_Y)
		enemy_panels[0].size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)
		enemy_panels[1].position = Vector2(ENEMY_FRONT_X, ROW_2_Y)
		enemy_panels[1].size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)
		enemy_panels[2].position = Vector2(ENEMY_FRONT_X, ROW_3_Y)
		enemy_panels[2].size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)
		enemy_panels[3].position = Vector2(ENEMY_BACK_X, ROW_1_Y)
		enemy_panels[3].size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)
		enemy_panels[4].position = Vector2(ENEMY_BACK_X, ROW_2_Y)
		enemy_panels[4].size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)
		enemy_panels[5].position = Vector2(ENEMY_BACK_X, ROW_3_Y)
		enemy_panels[5].size = Vector2(PANEL_WIDTH, ENEMY_HEIGHT)

	if ally_panels.size() >= 6:
		ally_panels[0].position = Vector2(ALLY_FRONT_X, ROW_1_Y)
		ally_panels[0].size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)
		ally_panels[1].position = Vector2(ALLY_FRONT_X, ROW_2_Y)
		ally_panels[1].size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)
		ally_panels[2].position = Vector2(ALLY_FRONT_X, ROW_3_Y)
		ally_panels[2].size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)
		ally_panels[3].position = Vector2(ALLY_BACK_X, ROW_1_Y)
		ally_panels[3].size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)
		ally_panels[4].position = Vector2(ALLY_BACK_X, ROW_2_Y)
		ally_panels[4].size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)
		ally_panels[5].position = Vector2(ALLY_BACK_X, ROW_3_Y)
		ally_panels[5].size = Vector2(PANEL_WIDTH, ALLY_HEIGHT)

## ========== LAYOUT SAVE/LOAD ==========

func save_manual_positions():
	"""Save all panel positions - ACCUMULATES each save + captures screenshot"""
	var save_path = "res://saved_layouts/battle_manual_positions.json"
	var absolute_path = ProjectSettings.globalize_path(save_path)

	# Create directory if it doesn't exist
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("saved_layouts"):
		dir.make_dir("saved_layouts")

	# Load existing saves
	var all_saves = {"saves": []}
	if FileAccess.file_exists(absolute_path):
		var file = FileAccess.open(absolute_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				all_saves = json.data
			file.close()

	# Create new save entry
	var save_number = all_saves.saves.size() + 1
	var new_save = {
		"save_number": save_number,
		"timestamp": Time.get_datetime_string_from_system(),
		"panels": {}
	}

	# Collect panel data
	for panel in all_battle_panels:
		if panel and panel.has_method("get_layout_data"):
			new_save.panels[panel.name] = panel.get_layout_data()

	# Append to save list
	all_saves.saves.append(new_save)

	# Write to file
	var file = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(all_saves, "\t")
		file.store_string(json_string)
		file.close()

		# Capture screenshot
		var screenshot_saved = await capture_choreography_screenshot(save_number)

		# Print save summary
		print("========================================")
		print("SAVE #", save_number, " RECORDED")
		print("========================================")
		print("Saved to: ", absolute_path)
		print("Total saves: ", all_saves.saves.size())
		if screenshot_saved:
			print("📸 Screenshot saved: choreography_frame_%03d.png" % save_number)
		print("\nCurrent position:")
		for panel_name in new_save.panels.keys():
			var panel_data = new_save.panels[panel_name]
			print("  ", panel_name, ":")
			print("    Position: (", panel_data.position.x, ", ", panel_data.position.y, ")")
			if panel_data.has("sprite_offset"):
				print("    Sprite offset: (", panel_data.sprite_offset.x, ", ", panel_data.sprite_offset.y, ")")
			if panel_data.has("sprite_scale"):
				print("    Sprite scale: ", panel_data.sprite_scale)
			if panel_data.has("current_direction"):
				print("    Direction: ", panel_data.current_direction)
		print("\nAll saves stored in: ", save_path)
		print("========================================\n")

		layout_saved.emit(save_number)
	else:
		print("ERROR: Could not save positions")

func load_battle_layout():
	"""Load panel positions and states from latest choreography save"""
	var save_path = "res://saved_layouts/battle_manual_positions.json"
	var absolute_path = ProjectSettings.globalize_path(save_path)

	if not FileAccess.file_exists(absolute_path):
		print("No saved choreography found, using defaults")
		return

	var file = FileAccess.open(absolute_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_text) == OK:
			var all_saves = json.data

			# Load the LAST save (most recent)
			if all_saves.has("saves") and all_saves.saves.size() > 0:
				var latest_save = all_saves.saves[all_saves.saves.size() - 1]
				var panels = latest_save.panels

				# Apply to each panel by name
				for panel in all_battle_panels:
					if panel and panels.has(panel.name):
						if panel.has_method("apply_layout_data"):
							panel.apply_layout_data(panels[panel.name])

				print("✓ Loaded choreography save #", latest_save.save_number, " from ", latest_save.timestamp)
				layout_loaded.emit(latest_save.save_number)
			else:
				print("No saves found in choreography file")
		else:
			print("ERROR: Failed to parse choreography JSON")
	else:
		print("ERROR: Could not open choreography file")

func save_battle_layout():
	"""Save panel positions to simple layout file (non-choreography)"""
	var layout_data = {}

	for panel in all_battle_panels:
		if panel and panel.has_method("get_layout_data"):
			layout_data[panel.name] = panel.get_layout_data()

	# Save to project directory
	var save_path = "res://saved_layouts/battle_layout.json"
	var absolute_path = ProjectSettings.globalize_path(save_path)

	# Create directory if it doesn't exist
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("saved_layouts"):
		dir.make_dir("saved_layouts")

	var file = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(layout_data, "\t")
		file.store_string(json_string)
		file.close()
		print("✓ Battle layout saved to: ", absolute_path)
	else:
		print("ERROR: Could not save battle layout")

func reset_battle_layout():
	"""Reset all panels to default positions and sizes"""
	auto_align_all_panels()
	print("✓ Battle layout reset to defaults")

## ========== SCREENSHOT CAPTURE ==========

func capture_choreography_screenshot(frame_number: int) -> bool:
	"""Capture screenshot of current battle choreography frame"""
	if not parent_node:
		print("⚠️ WARNING: Cannot capture screenshot - no parent_node set")
		return false

	# Wait one frame to ensure everything is rendered
	await get_tree().process_frame

	# Get the viewport image
	var img = parent_node.get_viewport().get_texture().get_image()

	# Create choreography folder
	var choreography_dir = "res://saved_layouts/battle_choreography/"
	var absolute_dir = ProjectSettings.globalize_path(choreography_dir)

	var dir = DirAccess.open("res://saved_layouts/")
	if not dir.dir_exists("battle_choreography"):
		dir.make_dir("battle_choreography")

	# Save with frame number (padded to 3 digits)
	var screenshot_path = choreography_dir + "choreography_frame_%03d.png" % frame_number
	var disk_path = ProjectSettings.globalize_path(screenshot_path)

	var error = img.save_png(disk_path)
	if error == OK:
		print("✓ Screenshot saved to: ", disk_path)
		return true
	else:
		print("ERROR: Failed to save screenshot: ", error)
		return false

## ========== UTILITY ==========

func get_panel_by_name(panel_name: String) -> Control:
	"""Find panel by name"""
	for panel in all_battle_panels:
		if panel and panel.name == panel_name:
			return panel
	return null

func is_panel_in_front_row(panel_index: int) -> bool:
	"""Check if panel index is in front row (0-2)"""
	return panel_index < 3

func is_panel_in_back_row(panel_index: int) -> bool:
	"""Check if panel index is in back row (3-5)"""
	return panel_index >= 3 and panel_index < 6
