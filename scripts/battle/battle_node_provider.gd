extends Node
## BattleNodeProvider - Extracted Node Reference Helper
## Centralizes all node reference getters from battle_window_v2.gd
## Safe extraction of pure getter functions with zero side effects

class_name BattleNodeProvider

## Node references provided by battle_window_v2 during initialization
var enemy_panels: Array = []
var ally_panels: Array = []

## Sprite references (directly stored, not calculated from panel paths)
var enemy_sprites: Array = []
var ally_sprites: Array = []

## UI element references
var enemy_names: Array = []
var ally_names: Array = []
var enemy_hp_bars: Array = []
var ally_hp_bars: Array = []
var enemy_hp_labels: Array = []
var ally_hp_labels: Array = []
var enemy_mp_bars: Array = []
var ally_mp_bars: Array = []
var enemy_mp_labels: Array = []
var ally_mp_labels: Array = []
var enemy_energy_bars: Array = []
var ally_energy_bars: Array = []
var enemy_energy_labels: Array = []
var ally_energy_labels: Array = []

func _init():
	"""Initialize empty provider - references set during initialize()"""
	pass

func initialize(enemy_panel_refs: Array, ally_panel_refs: Array, _ui_refs: Dictionary = {}) -> void:
	"""
	Initialize provider with panel references and auto-extract all UI elements.

	Args:
		enemy_panel_refs: Array of 6 enemy panel nodes
		ally_panel_refs: Array of 6 ally panel nodes
		_ui_refs: DEPRECATED - UI refs now auto-extracted from panels
	"""
	enemy_panels = enemy_panel_refs
	ally_panels = ally_panel_refs

	# Auto-extract all UI elements from panels
	_extract_ui_elements_from_panels()

	print("✓ BattleNodeProvider initialized:")
	print("  Panels: %d enemy, %d ally" % [enemy_panels.size(), ally_panels.size()])
	print("  Sprites: %d enemy, %d ally" % [enemy_sprites.size(), ally_sprites.size()])
	print("  HP Bars: %d enemy, %d ally" % [enemy_hp_bars.size(), ally_hp_bars.size()])


func _extract_ui_elements_from_panels() -> void:
	"""Extract all UI element references from panel nodes.
	This centralizes the repetitive node path lookups that were in battle_window_v2.gd"""

	# Clear existing arrays
	enemy_sprites = []
	ally_sprites = []
	enemy_names = []
	ally_names = []
	enemy_hp_bars = []
	ally_hp_bars = []
	enemy_hp_labels = []
	ally_hp_labels = []
	enemy_mp_bars = []
	ally_mp_bars = []
	enemy_mp_labels = []
	ally_mp_labels = []
	enemy_energy_bars = []
	ally_energy_bars = []
	enemy_energy_labels = []
	ally_energy_labels = []

	# Extract from enemy panels
	for i in range(enemy_panels.size()):
		var panel = enemy_panels[i]
		if not panel:
			continue
		var unit_node = panel.get_node_or_null("EnemyUnit%d" % (i + 1))
		if not unit_node:
			continue

		var sprite = unit_node.get_node_or_null("EnemySprite%d" % (i + 1))
		if sprite:
			enemy_sprites.append(sprite)

		var name_label = unit_node.get_node_or_null("EnemyName%d" % (i + 1))
		if name_label:
			enemy_names.append(name_label)

		var hp_bar = unit_node.get_node_or_null("EnemyHPBar%d" % (i + 1))
		if hp_bar:
			enemy_hp_bars.append(hp_bar)

		var hp_label = unit_node.get_node_or_null("EnemyHPLabel%d" % (i + 1))
		if hp_label:
			enemy_hp_labels.append(hp_label)

		var mp_bar = unit_node.get_node_or_null("EnemyMPBar%d" % (i + 1))
		if mp_bar:
			enemy_mp_bars.append(mp_bar)

		var mp_label = unit_node.get_node_or_null("EnemyMPLabel%d" % (i + 1))
		if mp_label:
			enemy_mp_labels.append(mp_label)

		var energy_bar = unit_node.get_node_or_null("EnemyEnergyBar%d" % (i + 1))
		if energy_bar:
			enemy_energy_bars.append(energy_bar)

		var energy_label = unit_node.get_node_or_null("EnemyEnergyLabel%d" % (i + 1))
		if energy_label:
			enemy_energy_labels.append(energy_label)

	# Extract from ally panels
	for i in range(ally_panels.size()):
		var panel = ally_panels[i]
		if not panel:
			continue
		var unit_node = panel.get_node_or_null("Ally%dUnit" % (i + 1))
		if not unit_node:
			continue

		var sprite = unit_node.get_node_or_null("Ally%dSprite" % (i + 1))
		if sprite:
			ally_sprites.append(sprite)

		var name_label = unit_node.get_node_or_null("Ally%dName" % (i + 1))
		if name_label:
			ally_names.append(name_label)

		var hp_bar = unit_node.get_node_or_null("Ally%dHPBar" % (i + 1))
		if hp_bar:
			ally_hp_bars.append(hp_bar)

		var hp_label = unit_node.get_node_or_null("Ally%dHPLabel" % (i + 1))
		if hp_label:
			ally_hp_labels.append(hp_label)

		var mp_bar = unit_node.get_node_or_null("Ally%dMPBar" % (i + 1))
		if mp_bar:
			ally_mp_bars.append(mp_bar)

		var mp_label = unit_node.get_node_or_null("Ally%dMPLabel" % (i + 1))
		if mp_label:
			ally_mp_labels.append(mp_label)

		var energy_bar = unit_node.get_node_or_null("Ally%dEnergyBar" % (i + 1))
		if energy_bar:
			ally_energy_bars.append(energy_bar)

		var energy_label = unit_node.get_node_or_null("Ally%dEnergyLabel" % (i + 1))
		if energy_label:
			ally_energy_labels.append(energy_label)

## ========== PANEL GETTERS ==========

func get_enemy_panels() -> Array:
	return enemy_panels

func get_ally_panels() -> Array:
	return ally_panels

func get_all_battle_panels() -> Array:
	var panels = get_enemy_panels()
	panels.append_array(get_ally_panels())
	return panels

## ========== SPRITE GETTERS ==========

func get_enemy_sprites() -> Array:
	return enemy_sprites

func get_ally_sprites() -> Array:
	return ally_sprites

## ========== NAME LABEL GETTERS ==========

func get_enemy_names() -> Array:
	return enemy_names

func get_ally_names() -> Array:
	return ally_names

## ========== HP BAR GETTERS ==========

func get_enemy_hp_bars() -> Array:
	return enemy_hp_bars

func get_ally_hp_bars() -> Array:
	return ally_hp_bars

## ========== HP LABEL GETTERS ==========

func get_enemy_hp_labels() -> Array:
	return enemy_hp_labels

func get_ally_hp_labels() -> Array:
	return ally_hp_labels

## ========== MP BAR GETTERS ==========

func get_enemy_mp_bars() -> Array:
	return enemy_mp_bars

func get_ally_mp_bars() -> Array:
	return ally_mp_bars

## ========== MP LABEL GETTERS ==========

func get_enemy_mp_labels() -> Array:
	return enemy_mp_labels

func get_ally_mp_labels() -> Array:
	return ally_mp_labels

## ========== ENERGY BAR GETTERS ==========

func get_enemy_energy_bars() -> Array:
	return enemy_energy_bars

func get_ally_energy_bars() -> Array:
	return ally_energy_bars

## ========== ENERGY LABEL GETTERS ==========

func get_enemy_energy_labels() -> Array:
	return enemy_energy_labels

func get_ally_energy_labels() -> Array:
	return ally_energy_labels
