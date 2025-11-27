class_name BattleLayoutManager
extends RefCounted
## Battle Layout Manager - Handles UI layout persistence
## Extracted from battle_window_v2.gd for modularity

const SAVE_PATH = "user://battle_ui_layout.json"
const LAYOUT_VERSION = 1


## Save all panel positions and sizes to user:// directory (client-side)
static func save_layout(enemy_panels: Array, ally_panels: Array, ui_panel: Control) -> void:
	var layout_data = {
		"version": LAYOUT_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"panels": {}
	}

	# Save all enemy panels
	for i in range(enemy_panels.size()):
		if enemy_panels[i]:
			layout_data.panels["enemy_%d" % i] = {
				"position": [enemy_panels[i].position.x, enemy_panels[i].position.y],
				"size": [enemy_panels[i].size.x, enemy_panels[i].size.y]
			}

	# Save all ally panels
	for i in range(ally_panels.size()):
		if ally_panels[i]:
			layout_data.panels["ally_%d" % i] = {
				"position": [ally_panels[i].position.x, ally_panels[i].position.y],
				"size": [ally_panels[i].size.x, ally_panels[i].size.y]
			}

	# Save UI panel
	if ui_panel:
		layout_data.panels["ui_panel"] = {
			"position": [ui_panel.position.x, ui_panel.position.y],
			"size": [ui_panel.size.x, ui_panel.size.y]
		}

	# Save to user:// directory (client-side persistent storage)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(layout_data, "\t"))
		file.close()


## Load panel positions and sizes from user:// directory
static func load_layout(enemy_panels: Array, ally_panels: Array, ui_panel: Control) -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		return

	var layout_data = json.data
	if not layout_data.has("panels"):
		return

	# Restore enemy panels
	for i in range(enemy_panels.size()):
		var key = "enemy_%d" % i
		if layout_data.panels.has(key) and enemy_panels[i]:
			var panel_data = layout_data.panels[key]
			enemy_panels[i].position = Vector2(panel_data.position[0], panel_data.position[1])
			enemy_panels[i].size = Vector2(panel_data.size[0], panel_data.size[1])

	# Restore ally panels
	for i in range(ally_panels.size()):
		var key = "ally_%d" % i
		if layout_data.panels.has(key) and ally_panels[i]:
			var panel_data = layout_data.panels[key]
			ally_panels[i].position = Vector2(panel_data.position[0], panel_data.position[1])
			ally_panels[i].size = Vector2(panel_data.size[0], panel_data.size[1])

	# Restore UI panel
	if layout_data.panels.has("ui_panel") and ui_panel:
		var panel_data = layout_data.panels["ui_panel"]
		ui_panel.position = Vector2(panel_data.position[0], panel_data.position[1])
		ui_panel.size = Vector2(panel_data.size[0], panel_data.size[1])
