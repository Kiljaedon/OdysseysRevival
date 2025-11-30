extends Node
class_name BattleFloatingOverlays

## Battle Floating Overlays System
## Manages HP/MP/Energy overlay bars that float above character sprites

# Overlay containers
var enemy_overlays: Array = []
var ally_overlays: Array = []

# Squad data references
var enemy_squad: Array = []
var ally_squad: Array = []

# UI Manager reference for sprite positions
var ui_manager = null

func _ready():
	"""Initialize the floating overlays system"""
	pass

func initialize(ui_mgr, enemies: Array, allies: Array):
	"""Initialize with UI manager and squad references"""
	ui_manager = ui_mgr
	enemy_squad = enemies
	ally_squad = allies

func create_overlays(parent_node: Node):
	"""Create small combined HP/MP/Energy bars that float over character sprites"""
	print("Creating floating HP/MP overlays...")

	# Create enemy stat overlays (HP + MP + Energy)
	for i in range(6):
		var overlay = create_combined_stat_overlay(true)  # true = is_enemy
		enemy_overlays.append(overlay)
		parent_node.add_child(overlay)
		overlay.visible = true  # Make visible by default

	# Create ally stat overlays (HP + MP + Energy)
	for i in range(6):
		var overlay = create_combined_stat_overlay(false)  # false = is_ally
		ally_overlays.append(overlay)
		parent_node.add_child(overlay)
		overlay.visible = true  # Make visible by default

	print("✓ Created %d enemy and %d ally floating overlays" % [enemy_overlays.size(), ally_overlays.size()])

func create_combined_stat_overlay(is_enemy: bool) -> VBoxContainer:
	"""Create a compact combined HP/MP/Energy bar overlay"""
	var container = VBoxContainer.new()
	container.z_index = 300  # Appear on top
	container.add_theme_constant_override("separation", 1)  # 1px spacing between bars

	# HP Bar (show for everyone)
	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(50, 6)  # Small: 50x6
	hp_bar.size = Vector2(50, 6)
	hp_bar.show_percentage = false
	var hp_style = StyleBoxFlat.new()
	hp_style.bg_color = Color(0, 0.8, 0, 1)  # Green
	hp_bar.add_theme_stylebox_override("fill", hp_style)
	container.add_child(hp_bar)

	# MP Bar (show for everyone - both enemies and allies)
	var mp_bar = ProgressBar.new()
	mp_bar.custom_minimum_size = Vector2(50, 5)  # Smaller: 50x5
	mp_bar.size = Vector2(50, 5)
	mp_bar.show_percentage = false
	var mp_style = StyleBoxFlat.new()
	mp_style.bg_color = Color(0, 0.5, 1, 1)  # Blue
	mp_bar.add_theme_stylebox_override("fill", mp_style)
	container.add_child(mp_bar)

	# Energy Bar (show for everyone - both enemies and allies)
	var energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(50, 5)  # Smaller: 50x5
	energy_bar.size = Vector2(50, 5)
	energy_bar.show_percentage = false
	var energy_style = StyleBoxFlat.new()
	energy_style.bg_color = Color(1, 0.8, 0, 1)  # Yellow/Gold
	energy_bar.add_theme_stylebox_override("fill", energy_style)
	container.add_child(energy_bar)

	return container

func update_overlays():
	"""Update positions and values of floating HP/MP/Energy overlays to match sprites"""
	if not ui_manager:
		return

	# Update enemy stat overlays (HP + MP + Energy)
	for i in range(min(enemy_overlays.size(), enemy_squad.size())):
		if not enemy_overlays[i] or enemy_overlays[i].get_child_count() < 3:
			continue

		var enemy = enemy_squad[i]
		if not enemy:
			continue

		# DEBUG: Print all keys in enemy dictionary
		print("  [DEBUG] Enemy %d keys: %s" % [i, enemy.keys()])

		# HP Bar (child 0)
		var hp_bar = enemy_overlays[i].get_child(0)
		var max_hp = enemy.get("max_hp", 100)
		var current_hp = enemy.get("hp", max_hp)
		print("  [OVERLAY] Enemy %d: HP %d/%d (overlay visible: %s, bar exists: %s)" % [i, current_hp, max_hp, enemy_overlays[i].visible, hp_bar != null])
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp

		# MP Bar (child 1)
		var mp_bar = enemy_overlays[i].get_child(1)
		var max_mp = enemy.get("max_mp", 50)
		var current_mp = enemy.get("mp", max_mp)
		mp_bar.max_value = max_mp
		mp_bar.value = current_mp

		# Energy Bar (child 2)
		var energy_bar = enemy_overlays[i].get_child(2)
		var max_energy = enemy.get("max_energy", 100)
		var current_energy = enemy.get("energy", max_energy)
		energy_bar.max_value = max_energy
		energy_bar.value = current_energy

	# Update ally stat overlays (HP + MP + Energy)
	for i in range(min(ally_overlays.size(), ally_squad.size())):
		if not ally_overlays[i] or ally_overlays[i].get_child_count() < 3:
			continue

		var ally = ally_squad[i]
		if not ally:
			continue

		# DEBUG: Print all keys in ally dictionary
		print("  [DEBUG] Ally %d keys: %s" % [i, ally.keys()])

		# HP Bar (child 0)
		var hp_bar = ally_overlays[i].get_child(0)
		var max_hp = ally.get("max_hp", 100)
		var current_hp = ally.get("hp", max_hp)
		print("  [OVERLAY] Ally %d: HP %d/%d (overlay visible: %s, bar exists: %s)" % [i, current_hp, max_hp, ally_overlays[i].visible, hp_bar != null])
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp

		# MP Bar (child 1)
		var mp_bar = ally_overlays[i].get_child(1)
		var max_mp = ally.get("max_mp", 50)
		var current_mp = ally.get("mp", max_mp)
		mp_bar.max_value = max_mp
		mp_bar.value = current_mp

		# Energy Bar (child 2)
		var energy_bar = ally_overlays[i].get_child(2)
		var max_energy = ally.get("max_energy", 100)
		var current_energy = ally.get("energy", max_energy)
		energy_bar.max_value = max_energy
		energy_bar.value = current_energy

	# Update positions
	update_positions()

func update_positions():
	"""Update positions of floating overlays to follow sprites"""
	if not ui_manager:
		return

	# Get sprite references from UI manager
	var enemy_sprites = ui_manager.get_enemy_sprites() if ui_manager else []
	var ally_sprites = ui_manager.get_ally_sprites() if ui_manager else []

	# Center enemy stat overlays above sprites
	for i in range(min(enemy_overlays.size(), enemy_sprites.size())):
		if not enemy_sprites[i] or not enemy_sprites[i] is Control:
			continue
		if not enemy_overlays[i]:
			continue

		var sprite_global_pos = enemy_sprites[i].global_position
		var sprite_size = enemy_sprites[i].size
		# Center horizontally: sprite center - half overlay width
		var centered_x = sprite_global_pos.x + (sprite_size.x / 2) - 25  # 25 = half of 50px width
		enemy_overlays[i].position = Vector2(centered_x, sprite_global_pos.y - 25)

	# Center ally stat overlays above sprites
	for i in range(min(ally_overlays.size(), ally_sprites.size())):
		if not ally_sprites[i] or not ally_sprites[i] is Control:
			continue
		if not ally_overlays[i]:
			continue

		var sprite_global_pos = ally_sprites[i].global_position
		var sprite_size = ally_sprites[i].size
		# Center horizontally: sprite center - half overlay width
		var centered_x = sprite_global_pos.x + (sprite_size.x / 2) - 25  # 25 = half of 50px width
		ally_overlays[i].position = Vector2(centered_x, sprite_global_pos.y - 25)

func hide_overlay(is_enemy: bool, index: int):
	"""Hide a specific overlay by index"""
	if is_enemy and index < enemy_overlays.size() and enemy_overlays[index]:
		enemy_overlays[index].visible = false
	elif not is_enemy and index < ally_overlays.size() and ally_overlays[index]:
		ally_overlays[index].visible = false

func hide_panel_title_bars(get_enemy_panels_func: Callable, get_ally_panels_func: Callable):
	"""Hide developer title bars on all character panels"""
	var all_panels = []
	all_panels.append_array(get_enemy_panels_func.call())
	all_panels.append_array(get_ally_panels_func.call())

	for panel in all_panels:
		if not panel:
			continue

		# Hide various types of title bars
		if panel.has_node("TitleBar"):
			panel.get_node("TitleBar").visible = false

		if panel.has_node("LockButton"):
			panel.get_node("LockButton").visible = false

		# Check for title bars as direct children with various names
		if panel and panel.is_node_ready():
			for child in panel.get_children():
				# Hide any node that looks like a title bar
				var child_name = child.name.to_lower()
				if "title" in child_name or "header" in child_name or child_name == "enemy" or child_name == "ally":
					child.visible = false
					print("  Hidden title element: %s" % child.name)

				# Hide RichTextLabel or Label at top of panel (likely title)
				if (child is RichTextLabel or child is Label) and child.position.y < 30:
					child.visible = false
					print("  Hidden top label: %s" % child.name)

	print("✓ Hidden title bars on all panels")

func hide_name_labels(get_enemy_names_func: Callable, get_ally_names_func: Callable):
	"""Hide character name labels (they block the view of sprites)"""
	var enemy_names = get_enemy_names_func.call()
	var ally_names = get_ally_names_func.call()

	for name_label in enemy_names:
		if name_label:
			name_label.visible = false

	for name_label in ally_names:
		if name_label:
			name_label.visible = false

	print("✓ Hidden %d enemy and %d ally name labels" % [enemy_names.size(), ally_names.size()])

func hide_large_hp_bars(get_enemy_panels_func: Callable, get_ally_panels_func: Callable):
	"""Hide the large HP/MP bars in panels (we only show small floating ones)"""
	print("Hiding large HP/MP bars...")

	# Hide ALL child bars/labels in enemy panels directly
	var enemy_panels = get_enemy_panels_func.call()
	for i in range(enemy_panels.size()):
		if enemy_panels[i]:
			var unit_node = enemy_panels[i].get_node_or_null("EnemyUnit%d" % (i + 1))
			if unit_node:
				# Hide all ProgressBar and Label children
				for child in unit_node.get_children():
					if child is ProgressBar or (child is Label and ("HP" in child.name or "MP" in child.name or "Energy" in child.name)):
						child.visible = false
						print("  Hidden %s in enemy panel %d" % [child.name, i + 1])

	# Hide ALL child bars/labels in ally panels directly
	var ally_panels = get_ally_panels_func.call()
	for i in range(ally_panels.size()):
		if ally_panels[i]:
			var unit_node = ally_panels[i].get_node_or_null("Ally%dUnit" % (i + 1))
			if unit_node:
				# Hide all ProgressBar and Label children
				for child in unit_node.get_children():
					if child is ProgressBar or (child is Label and ("HP" in child.name or "MP" in child.name or "Energy" in child.name)):
						child.visible = false
						print("  Hidden %s in ally panel %d" % [child.name, i + 1])

	print("✓ Large HP/MP bars hidden")
