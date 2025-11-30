extends Node
class_name ServerNPCManager

## Manages NPC spawning, AI, movement, and lifecycle
## Separated from ServerWorld for modularity

# Dependencies (set by ServerWorld)
var server_world: Node = null
var network_handler = null
var spatial_manager = null
var network_sync = null
var movement_validator = null
var player_manager = null
var map_manager = null  # For collision-free spawn checking

# NPC state
var server_npcs: Dictionary = {}            # npc_id -> {npc_name, position, target, state, npc_type}
var npc_positions: Dictionary = {}          # npc_id -> Vector2
var next_npc_id: int = 1                    # Auto-incrementing NPC ID


func _ready():
	pass


func initialize(server_ref, net_handler, spatial_mgr, net_sync, move_validator, player_mgr, map_mgr = null):
	"""Initialize NPCManager with dependencies from ServerWorld"""
	server_world = server_ref
	network_handler = net_handler
	spatial_manager = spatial_mgr
	network_sync = net_sync
	movement_validator = move_validator
	player_manager = player_mgr
	map_manager = map_mgr


# ========== NPC SPAWNING ==========

func spawn_server_npcs():
	"""Spawn initial NPCs on the server - loads from characters/npcs/ directory"""
	log_message("[NPC] Loading NPC spawn configurations...")

	# Map boundaries (sample_map.tmx: 20x15 tiles, 32px tiles, 4x scale)
	var map_width = 20 * 32 * 4  # 2560 pixels
	var map_height = 15 * 32 * 4  # 1920 pixels
	var padding = 128.0  # Keep NPCs away from edges

	# Define available NPC types
	var available_types = ["Rogue", "Goblin", "OrcWarrior", "DarkMage", "EliteGuard", "RogueBandit"]
	var npc_spawn_configs = []
	
	# RANDOM SPAWN GENERATION (Spec 019)
	# Generate 20 random spawns
	for i in range(20):
		var type = available_types.pick_random()
		var pos = Vector2(
			randf_range(padding, map_width - padding),
			randf_range(padding, map_height - padding)
		)
		npc_spawn_configs.append({
			"type": type,
			"position": pos,
			"wander_radius": 256.0
		})

	# Spawn each configured NPC
	for config in npc_spawn_configs:
		var npc_type = config.type
		var spawn_pos = config.position
		var wander_radius = config.get("wander_radius", 384.0)

		# Check if NPC character data exists
		var npc_file = "res://characters/npcs/" + npc_type + ".json"
		if not FileAccess.file_exists(npc_file):
			log_message("[NPC] WARNING: NPC file not found: %s - skipping" % npc_file)
			continue

		# Load NPC JSON data (including animations)
		var npc_data = load_npc_data(npc_type)
		if npc_data.is_empty():
			log_message("[NPC] WARNING: Failed to load NPC data for: %s - skipping" % npc_type)
			continue

		# COLLISION-FREE SPAWN: Find nearest free tile if spawn position is blocked
		if map_manager:
			spawn_pos = map_manager.find_nearest_free_spawn("sample_map", spawn_pos)

		# Create NPC instance
		var npc_id = next_npc_id
		next_npc_id += 1

		# Calculate Level and Scale Stats
		var level_range = npc_data.get("level_range", {"min": 1, "max": 1})
		var min_lvl = int(level_range.get("min", 1))
		var max_lvl = int(level_range.get("max", 1))
		var level = randi_range(min_lvl, max_lvl)

		# Apply scaling
		_scale_npc_stats(npc_data, level)

		server_npcs[npc_id] = {
			"npc_name": "npc:" + npc_type,
			"npc_type": npc_type,
			"character_name": npc_type,  # Used by client for animation lookup
			"position": spawn_pos,
			"spawn_position": spawn_pos,
			"target": spawn_pos,
			"state": "idle",
			"idle_timer": randf_range(1.0, 3.0),  # Random idle time
			"wander_radius": wander_radius,
			"move_speed": 100.0,
			"map_width": map_width,
			"map_height": map_height,
			"map_padding": padding,
			"animations": npc_data.get("animations", {}),
			"level": level,
			"hp": npc_data.get("hp", 100),
			"max_hp": npc_data.get("max_hp", 100),
			"base_stats": npc_data.get("base_stats", {}),
			"ai_archetype": npc_data.get("ai_archetype", "AGGRESSIVE")
		}
		npc_positions[npc_id] = spawn_pos

		# Register NPC in spatial manager
		if spatial_manager:
			spatial_manager.register_entity(npc_id, spawn_pos, "npc")

		log_message("[NPC] Spawned NPC #%d: %s (Lv %d) at %s" % [npc_id, npc_type, level, str(spawn_pos)])

	log_message("[NPC] Spawned %d NPCs total" % server_npcs.size())

	# Broadcast all NPCs to all connected clients
	if network_handler and player_manager:
		for peer_id in player_manager.connected_players:
			for npc_id in server_npcs:
				network_handler.send_npc_spawn(peer_id, npc_id, server_npcs[npc_id])


func _scale_npc_stats(npc_data: Dictionary, level: int) -> void:
	"""Scale NPC stats based on level (Mutation - modifies npc_data in place)"""
	if level <= 1:
		return # No scaling needed
		
	# Scaling factors
	var stat_growth = 0.05 # 5% per level
	var hp_growth = 0.10   # 10% per level
	
	var multiplier_stats = 1.0 + (level * stat_growth)
	var multiplier_hp = 1.0 + (level * hp_growth)
	
	# Scale HP
	if npc_data.has("hp"):
		npc_data["hp"] = int(npc_data["hp"] * multiplier_hp)
	if npc_data.has("max_hp"):
		npc_data["max_hp"] = int(npc_data["max_hp"] * multiplier_hp)
	
	# Scale Attributes
	if npc_data.has("base_stats"):
		for stat in npc_data.base_stats:
			npc_data.base_stats[stat] = int(npc_data.base_stats[stat] * multiplier_stats)
			
	# Scale Derived (if present)
	if npc_data.has("derived_stats"):
		for stat in npc_data.derived_stats:
			npc_data.derived_stats[stat] = int(npc_data.derived_stats[stat] * multiplier_stats)


# ========== NPC AI & MOVEMENT ==========

func update_npcs(delta: float):
	"""Update NPC AI and movement with collision validation"""
	for npc_id in server_npcs.keys():
		var npc = server_npcs[npc_id]

		if npc.state == "idle":
			npc.idle_timer -= delta
			if npc.idle_timer <= 0:
				# Pick new wander target - try up to 10 times to find a free spot
				var spawn = npc.spawn_position
				var radius = npc.wander_radius
				var target = Vector2.ZERO
				var found_valid_target = false

				for _attempt in range(10):
					var angle = randf() * 2 * PI
					var distance = randf() * radius
					target = spawn + Vector2(cos(angle), sin(angle)) * distance

					# Clamp target to map boundaries
					var padding = npc.map_padding
					target.x = clamp(target.x, padding, npc.map_width - padding)
					target.y = clamp(target.y, padding, npc.map_height - padding)

					# Check if target is in a collision tile
					if map_manager and map_manager.is_position_blocked("sample_map", target):
						continue  # Try another target

					found_valid_target = true
					break

				if found_valid_target:
					npc.target = target
					npc.state = "moving"
				else:
					# Couldn't find valid target, stay idle longer
					npc.idle_timer = randf_range(1.0, 2.0)

		elif npc.state == "moving":
			var current_pos = npc_positions[npc_id]
			var direction = (npc.target - current_pos).normalized()
			var distance = current_pos.distance_to(npc.target)

			if distance < 5.0:
				# Reached target, go idle
				npc.state = "idle"
				npc.idle_timer = randf_range(1.0, 3.0)
			else:
				# Move toward target
				var movement = direction * npc.move_speed * delta
				var new_pos = current_pos + movement

				# Clamp position to map boundaries
				var padding = npc.map_padding
				new_pos.x = clamp(new_pos.x, padding, npc.map_width - padding)
				new_pos.y = clamp(new_pos.y, padding, npc.map_height - padding)

				# Check if new position is in a collision tile
				if map_manager and map_manager.is_position_blocked("sample_map", new_pos):
					# Would enter collision - stop and pick new target
					npc.state = "idle"
					npc.idle_timer = randf_range(0.3, 0.8)
					continue

				# Check collision with movement validator
				if movement_validator:
					var validation = movement_validator.validate_movement(current_pos, new_pos, delta)
					if not validation.valid:
						# Hit a wall - pick new target immediately
						npc.state = "idle"
						npc.idle_timer = randf_range(0.3, 0.8)  # Short idle before picking new path
						continue

				npc_positions[npc_id] = new_pos
				npc.position = new_pos

				# Update spatial manager
				if spatial_manager:
					spatial_manager.update_entity_position(npc_id, new_pos)


# ========== NPC POSITION BROADCASTING ==========

func broadcast_npc_positions():
	"""Send NPC positions using binary packets with spatial culling"""
	if npc_positions.is_empty() or not network_sync or not spatial_manager:
		return

	# Use binary packet system with spatial culling to only nearby players
	network_sync.broadcast_npc_positions(npc_positions, spatial_manager)


# ========== HELPER METHODS ==========

func log_message(msg: String):
	"""Log message via ServerWorld if available"""
	if server_world and server_world.has_method("log_message"):
		server_world.log_message(msg)
	else:
		print(msg)


func log_activity(msg: String):
	"""Log activity via ServerWorld if available"""
	if server_world and server_world.has_method("log_activity"):
		server_world.log_activity(msg)
	else:
		print(msg)


func load_npc_data(npc_type: String) -> Dictionary:
	"""Load NPC data (including animations) from characters/npcs/{npc_type}.json"""
	var npc_file = "res://characters/npcs/%s.json" % npc_type

	if not FileAccess.file_exists(npc_file):
		log_message("[NPC] ERROR: NPC file not found: %s" % npc_file)
		return {}

	var file = FileAccess.open(npc_file, FileAccess.READ)
	if not file:
		log_message("[NPC] ERROR: Could not open NPC file: %s" % npc_file)
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		log_message("[NPC] ERROR: Failed to parse NPC JSON: %s" % npc_file)
		return {}

	var data = json.data
	# Ensure HP/MP are initialized
	if not data.has("hp"):
		if data.has("derived_stats"):
			data["hp"] = data.derived_stats.get("max_hp", 100)
		else:
			data["hp"] = 100
	
	# Debug print
	print("[NPC] Loaded data for %s - HP: %d" % [npc_type, data.get("hp", -999)])
			
	return data


func send_npcs_to_player(peer_id: int):
	"""Send all existing NPCs to a specific player when they connect"""
	if not network_handler:
		log_message("[NPC] ERROR: Cannot send NPCs - network_handler is null")
		return
	
	log_message("[NPC] Sending %d NPCs to peer %d" % [server_npcs.size(), peer_id])
	
	for npc_id in server_npcs:
		network_handler.send_npc_spawn(peer_id, npc_id, server_npcs[npc_id])
	
	log_message("[NPC] Finished sending NPCs to peer %d" % peer_id)
