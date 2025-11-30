class_name UILayoutManager
extends Node

## Manages UI panel layout persistence for the development client.
## Saves and loads draggable panel positions, sizes, and states to disk.
##
## Features:
## - Save panel layouts to JSON file in user:// directory
## - Load previously saved layouts on startup
## - Reset panels to default positions
## - Panel identification by title or name
## - Timestamped saves for debugging
##
## Dependencies:
## - DraggablePanel script with get_layout_data() and apply_layout_data() methods
##
## Storage:
## - Location: user://dev_client_layout.json
## - Format: JSON with version and timestamp tracking
## - Scope: Client-side persistent storage only
##
## Usage:
## var layout_mgr = UILayoutManager.new()
## layout_mgr.initialize(draggable_panels)
## layout_mgr.save_ui_layout()
## layout_mgr.load_ui_layout()

var draggable_panels: Array[Panel] = []
var ui_layout_file: String = "user://dev_client_layout.json"

func initialize(panels: Array[Panel]) -> void:
	"""Initialize layout manager with panel references."""
	draggable_panels = panels
	print("[UILayoutManager] Initialized with %d panels" % panels.size())

func save_ui_layout() -> void:
	"""Save all draggable panel positions and states (uses panel names as keys)."""
	print("💾 Saving UI layout...")
	var layout_data = {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"panels": {}
	}

	for panel in draggable_panels:
		if panel and panel.has_method("get_layout_data"):
			# Use panel title as key for easier identification
			var panel_key = panel.panel_title if "panel_title" in panel else panel.name
			layout_data.panels[panel_key] = panel.get_layout_data()

	# Save to user:// directory (client-side persistent storage)
	var save_path = ui_layout_file

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(layout_data, "\t")
		file.store_string(json_string)
		file.close()
		print("✅ Layout saved: %d panels → %s" % [layout_data.panels.size(), save_path])
	else:
		print("❌ ERROR: Could not save UI layout")

func load_ui_layout() -> void:
	"""Load draggable panel positions and states."""
	print("📂 Loading UI layout...")
	var save_path = ui_layout_file

	if not FileAccess.file_exists(save_path):
		print("ℹ️ No saved layout found, using defaults")
		return

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_text) == OK:
			var layout_data = json.data

			if layout_data.has("panels"):
				var loaded_count = 0
				for panel in draggable_panels:
					if panel and panel.has_method("apply_layout_data"):
						var panel_key = panel.panel_title if "panel_title" in panel else panel.name
						if layout_data.panels.has(panel_key):
							panel.apply_layout_data(layout_data.panels[panel_key])
							loaded_count += 1

				print("✅ Layout loaded: %d panels restored from %s" % [loaded_count, save_path])
			else:
				print("⚠️ WARNING: Old layout format detected, using defaults")
		else:
			print("❌ ERROR: Failed to parse layout JSON")
	else:
		print("❌ ERROR: Could not open layout file")

func reset_ui_layout() -> void:
	"""Reset panels to default positions."""
	print("Resetting UI layout...")
	if FileAccess.file_exists(ui_layout_file):
		DirAccess.remove_absolute(ui_layout_file)

	# Reset panels to default positions (2 panels total)
	if draggable_panels.size() >= 2:
		draggable_panels[0].position = Vector2(300, 10)     # Game Screen
		draggable_panels[1].position = Vector2(10, 10)      # Character Tester
