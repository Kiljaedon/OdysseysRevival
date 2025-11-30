@tool
class_name OdysseyMapProperties extends Window

signal properties_applied(map_data: GSMMOMapData)

var current_map: GSMMOMapData

# UI References
@onready var map_name_edit = $VBox/BasicProperties/GridContainer/MapNameEdit
@onready var exit_up_spin = $VBox/Exits/GridContainer/ExitUpSpin
@onready var exit_down_spin = $VBox/Exits/GridContainer/ExitDownSpin
@onready var exit_left_spin = $VBox/Exits/GridContainer/ExitLeftSpin
@onready var exit_right_spin = $VBox/Exits/GridContainer/ExitRightSpin

@onready var boot_map_spin = $VBox/Locations/GridContainer/BootMapSpin
@onready var boot_x_spin = $VBox/Locations/GridContainer/BootXSpin
@onready var boot_y_spin = $VBox/Locations/GridContainer/BootYSpin
@onready var death_map_spin = $VBox/Locations/GridContainer/DeathMapSpin
@onready var death_x_spin = $VBox/Locations/GridContainer/DeathXSpin
@onready var death_y_spin = $VBox/Locations/GridContainer/DeathYSpin

@onready var npc_spin = $VBox/GameSettings/GridContainer/NPCSpin
@onready var midi_spin = $VBox/GameSettings/GridContainer/MidiSpin

@onready var flag_indoors = $VBox/Flags/GridContainer/FlagIndoors
@onready var flag_always_dark = $VBox/Flags/GridContainer/FlagAlwaysDark
@onready var flag_arena = $VBox/Flags/GridContainer/FlagArena
@onready var flag_no_monsters = $VBox/Flags/GridContainer/FlagNoMonsters
@onready var flag_double_monsters = $VBox/Flags/GridContainer/FlagDoubleMonsters

@onready var monster_spawns_container = $VBox/MonsterSpawns/ScrollContainer/MonsterSpawnsGrid

@onready var ok_button = $VBox/Buttons/OKButton
@onready var cancel_button = $VBox/Buttons/CancelButton

func _ready():
	await get_tree().process_frame
	if not is_node_ready():
		return

	if ok_button:
		ok_button.pressed.connect(_on_ok_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

	_create_monster_spawn_controls()

func _create_monster_spawn_controls():
	if not monster_spawns_container:
		return

	monster_spawns_container.columns = 3

	# Create 10 monster spawn rows (0-9) like Odyssey
	for i in range(10):
		var spawn_label = Label.new()
		spawn_label.text = "Spawn " + str(i) + ":"

		var monster_spin = SpinBox.new()
		monster_spin.min_value = 0
		monster_spin.max_value = 9999
		monster_spin.name = "MonsterSpin" + str(i)

		var rate_spin = SpinBox.new()
		rate_spin.min_value = 0
		rate_spin.max_value = 255
		rate_spin.name = "RateSpin" + str(i)

		monster_spawns_container.add_child(spawn_label)
		monster_spawns_container.add_child(monster_spin)
		monster_spawns_container.add_child(rate_spin)

func load_map_data(map_data: GSMMOMapData):
	current_map = map_data
	if not current_map:
		return

	# Basic properties
	if map_name_edit:
		map_name_edit.text = current_map.map_name

	# Exits
	if exit_up_spin:
		exit_up_spin.value = current_map.exit_up
	if exit_down_spin:
		exit_down_spin.value = current_map.exit_down
	if exit_left_spin:
		exit_left_spin.value = current_map.exit_left
	if exit_right_spin:
		exit_right_spin.value = current_map.exit_right

	# Boot and death locations
	if boot_map_spin:
		boot_map_spin.value = current_map.death_location_map  # Using death location as boot for now
	if boot_x_spin:
		boot_x_spin.value = current_map.death_location_pos.x
	if boot_y_spin:
		boot_y_spin.value = current_map.death_location_pos.y
	if death_map_spin:
		death_map_spin.value = current_map.death_location_map
	if death_x_spin:
		death_x_spin.value = current_map.death_location_pos.x
	if death_y_spin:
		death_y_spin.value = current_map.death_location_pos.y

	# Game settings
	if npc_spin:
		npc_spin.value = current_map.default_npc
	if midi_spin:
		midi_spin.value = 1  # TODO: Add MIDI field to map data

	# Flags - decode bit flags
	var flags = current_map.flags
	if flag_indoors:
		flag_indoors.button_pressed = (flags & 1) != 0
	if flag_always_dark:
		flag_always_dark.button_pressed = (flags & 2) != 0
	if flag_arena:
		flag_arena.button_pressed = (flags & 4) != 0
	if flag_no_monsters:
		flag_no_monsters.button_pressed = (flags & 8) != 0
	if flag_double_monsters:
		flag_double_monsters.button_pressed = (flags & 16) != 0

	# Monster spawns
	if monster_spawns_container:
		for i in range(10):
			var monster_spin = monster_spawns_container.get_node_or_null("MonsterSpin" + str(i))
			var rate_spin = monster_spawns_container.get_node_or_null("RateSpin" + str(i))

			if monster_spin and rate_spin and i < current_map.monster_spawns.size():
				var spawn_data = current_map.monster_spawns[i]
				if spawn_data is Dictionary:
					monster_spin.value = spawn_data.get("monster", 0)
					rate_spin.value = spawn_data.get("rate", 0)

func _on_ok_pressed():
	if not current_map:
		return

	# Save basic properties
	if map_name_edit:
		current_map.map_name = map_name_edit.text

	# Save exits
	if exit_up_spin:
		current_map.exit_up = int(exit_up_spin.value)
	if exit_down_spin:
		current_map.exit_down = int(exit_down_spin.value)
	if exit_left_spin:
		current_map.exit_left = int(exit_left_spin.value)
	if exit_right_spin:
		current_map.exit_right = int(exit_right_spin.value)

	# Save locations
	if death_map_spin:
		current_map.death_location_map = int(death_map_spin.value)
	if death_x_spin and death_y_spin:
		current_map.death_location_pos = Vector2i(int(death_x_spin.value), int(death_y_spin.value))

	# Save game settings
	if npc_spin:
		current_map.default_npc = int(npc_spin.value)

	# Save flags - encode as bit flags
	var flags = 0
	if flag_indoors and flag_indoors.button_pressed:
		flags |= 1
	if flag_always_dark and flag_always_dark.button_pressed:
		flags |= 2
	if flag_arena and flag_arena.button_pressed:
		flags |= 4
	if flag_no_monsters and flag_no_monsters.button_pressed:
		flags |= 8
	if flag_double_monsters and flag_double_monsters.button_pressed:
		flags |= 16
	current_map.flags = flags

	# Save monster spawns
	if monster_spawns_container:
		current_map.monster_spawns.clear()
		for i in range(10):
			var monster_spin = monster_spawns_container.get_node_or_null("MonsterSpin" + str(i))
			var rate_spin = monster_spawns_container.get_node_or_null("RateSpin" + str(i))

			if monster_spin and rate_spin:
				current_map.monster_spawns.append({
					"monster": int(monster_spin.value),
					"rate": int(rate_spin.value)
				})

	properties_applied.emit(current_map)
	hide()

func _on_cancel_pressed():
	hide()