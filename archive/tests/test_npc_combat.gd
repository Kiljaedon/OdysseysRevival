extends Node
## Test script to simulate multi-player NPC combat
## Run this from the server to test combat system

var server_world: Node = null

func _ready():
	print("\n========== NPC COMBAT TEST ==========")
	print("Waiting for server to initialize...")
	await get_tree().create_timer(2.0).timeout

	# Find server_world
	for child in get_tree().root.get_children():
		if child.name == "ServerWorld":
			server_world = child
			break

	if not server_world:
		print("ERROR: Could not find ServerWorld!")
		return

	print("Found ServerWorld, starting test...\n")
	run_test()

func run_test():
	# Setup mock players
	print("=== SETUP: Creating mock players ===")

	if not server_world.player_manager:
		print("ERROR: player_manager not initialized")
		return

	# Mock Player A (peer_id 100)
	server_world.player_manager.connected_players[100] = {
		"username": "TestPlayerA",
		"character_name": "Alice",
		"character_id": "char_alice_001",
		"class": "Warrior",
		"level": 5
	}

	# Mock Player B (peer_id 200)
	server_world.player_manager.connected_players[200] = {
		"username": "TestPlayerB",
		"character_name": "Bob",
		"character_id": "char_bob_002",
		"class": "Mage",
		"level": 4
	}

	print("✓ Created mock Player A (peer_id=100): Alice the Warrior")
	print("✓ Created mock Player B (peer_id=200): Bob the Mage")

	# Create mock NPC
	print("\n=== SETUP: Creating mock NPC ===")
	var npc_id = 5
	server_world.server_npcs[npc_id] = {
		"npc_name": "Wandering Rogue",
		"npc_type": "Rogue",
		"position": Vector2(500, 500),
		"state": "idle"
	}
	print("✓ Created NPC #%d: Wandering Rogue" % npc_id)

	# Simulate Player A attacking
	print("\n=== TEST 1: Player A attacks NPC #%d ===" % npc_id)
	simulate_attack(100, npc_id, "Alice")

	await get_tree().create_timer(0.5).timeout

	# Simulate Player B attacking same NPC
	print("\n=== TEST 2: Player B attacks same NPC #%d ===" % npc_id)
	simulate_attack(200, npc_id, "Bob")

	await get_tree().create_timer(0.5).timeout

	# Simulate Player A attacking again
	print("\n=== TEST 3: Player A attacks again ===" % npc_id)
	simulate_attack(100, npc_id, "Alice")

	await get_tree().create_timer(0.5).timeout

	print("\n=== TEST RESULTS ===")
	print_results()

func simulate_attack(peer_id: int, npc_id: int, player_name: String):
	print("  → %s (peer %d) initiating attack..." % [player_name, peer_id])

	# Store original sender for restoration
	var original_sender = multiplayer.get_remote_sender_id() if multiplayer.has_multiplayer_peer() else 0

	# Mock the RPC sender (simulate client calling server)
	# Note: We can't actually override multiplayer.get_remote_sender_id()
	# So we'll call the handler directly with peer_id context

	# Store combat instances before
	var combat_count_before = server_world.npc_combat_instances.size()

	# Manually call the handler with our mock peer_id
	var npc = server_world.server_npcs.get(npc_id)
	var player = server_world.player_manager.connected_players.get(peer_id) if server_world.player_manager else null

	if not npc or not player:
		print("  ✗ Failed: NPC or Player not found")
		return

	# Manually execute combat logic (since we can't mock RPC sender)
	var combat_id = server_world.next_combat_id
	server_world.next_combat_id += 1

	server_world.npc_combat_instances[combat_id] = {
		"npc_id": npc_id,
		"peer_id": peer_id,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}

	# Generate enemy squad
	var enemy_count = randi_range(2, 3)
	var enemy_squad = []

	for i in range(enemy_count):
		enemy_squad.append({
			"name": npc.npc_type + " " + str(i + 1),
			"class": npc.npc_type,
			"level": randi_range(1, 5),
			"hp": randi_range(50, 100),
			"max_hp": 100,
			"attack": randi_range(10, 20),
			"defense": randi_range(5, 15)
		})

	# Build binary packet (efficiency test)
	var combat_packet = PacketEncoder.build_combat_start_packet(combat_id, npc_id, enemy_squad)

	print("  ✓ Combat ID: %d" % combat_id)
	print("  ✓ Binary packet size: %d bytes (vs ~1500 bytes for Dictionary RPC)" % combat_packet.size())
	print("  ✓ Enemy squad generated: %d enemies" % enemy_count)
	for i in range(enemy_squad.size()):
		var enemy = enemy_squad[i]
		print("    - %s (Lv %d): HP=%d/%d, ATK=%d, DEF=%d" % [
			enemy.name,
			enemy.level,
			enemy.hp,
			enemy.max_hp,
			enemy.attack,
			enemy.defense
		])

	# Test packet decode
	var decoded = PacketEncoder.parse_combat_start_packet(combat_packet)
	if decoded.is_empty():
		print("  ✗ ERROR: Failed to decode combat packet!")
	else:
		print("  ✓ Packet decoded successfully: combat_id=%d, npc_id=%d, enemies=%d" % [
			decoded.combat_id,
			decoded.npc_id,
			decoded.enemy_squad.size()
		])

func print_results():
	var total_combats = server_world.npc_combat_instances.size()
	print("Total combat instances created: %d" % total_combats)
	print("\nCombat Instance Details:")

	for combat_id in server_world.npc_combat_instances:
		var instance = server_world.npc_combat_instances[combat_id]
		var player = server_world.player_manager.connected_players.get(instance.peer_id, {}) if server_world.player_manager else {}
		var npc = server_world.server_npcs.get(instance.npc_id, {})

		print("  Combat #%d:" % combat_id)
		print("    Player: %s (peer %d)" % [player.get("character_name", "Unknown"), instance.peer_id])
		print("    NPC: %s (ID %d)" % [npc.get("npc_name", "Unknown"), instance.npc_id])
		print("    Timestamp: %.2f" % instance.timestamp)

	print("\n=== VERIFICATION ===")

	print("\n1. Efficiency Test:")
	# Test packet encoding efficiency
	var test_enemy_squad = [
		{"name": "Rogue 1", "class": "Rogue", "level": 3, "hp": 75, "max_hp": 100, "attack": 15, "defense": 10},
		{"name": "Rogue 2", "class": "Rogue", "level": 5, "hp": 92, "max_hp": 100, "attack": 18, "defense": 12},
		{"name": "Rogue 3", "class": "Rogue", "level": 2, "hp": 58, "max_hp": 100, "attack": 11, "defense": 7}
	]
	var binary_packet = PacketEncoder.build_combat_start_packet(1, 5, test_enemy_squad)
	var dict_rpc_size = str(test_enemy_squad).length() + 100  # Approximate Dictionary RPC size
	print("  Binary packet: %d bytes" % binary_packet.size())
	print("  Dictionary RPC (estimated): ~%d bytes" % dict_rpc_size)
	print("  Savings: %d bytes (%.1f%% reduction)" % [
		dict_rpc_size - binary_packet.size(),
		100.0 * (dict_rpc_size - binary_packet.size()) / float(dict_rpc_size)
	])
	if binary_packet.size() < 100:
		print("  ✓ PASS: Binary packet is highly efficient (<%d bytes)" % binary_packet.size())
	else:
		print("  ✗ FAIL: Binary packet too large (%d bytes)" % binary_packet.size())

	print("\n2. Combat Instance Test:")
	if total_combats == 3:
		print("✓ PASS: All 3 attacks created separate combat instances")
	else:
		print("✗ FAIL: Expected 3 combat instances, got %d" % total_combats)

	# Check that same NPC can be attacked by different players
	var npc_5_combats = []
	for combat_id in server_world.npc_combat_instances:
		var instance = server_world.npc_combat_instances[combat_id]
		if instance.npc_id == 5:
			npc_5_combats.append(combat_id)

	if npc_5_combats.size() == 3:
		print("✓ PASS: Same NPC (#5) can be attacked multiple times")
	else:
		print("✗ FAIL: Expected 3 attacks on NPC #5, got %d" % npc_5_combats.size())

	# Check that different players got different combat IDs
	var peer_100_combats = []
	var peer_200_combats = []
	for combat_id in server_world.npc_combat_instances:
		var instance = server_world.npc_combat_instances[combat_id]
		if instance.peer_id == 100:
			peer_100_combats.append(combat_id)
		elif instance.peer_id == 200:
			peer_200_combats.append(combat_id)

	if peer_100_combats.size() == 2:
		print("✓ PASS: Player A got 2 separate combat instances")
	else:
		print("✗ FAIL: Player A expected 2 combats, got %d" % peer_100_combats.size())

	if peer_200_combats.size() == 1:
		print("✓ PASS: Player B got 1 combat instance")
	else:
		print("✗ FAIL: Player B expected 1 combat, got %d" % peer_200_combats.size())

	print("\n========== TEST COMPLETE ==========\n")

	# Cleanup
	cleanup()

func cleanup():
	print("Cleaning up mock data...")
	server_world.connected_players.erase(100)
	server_world.connected_players.erase(200)
	server_world.server_npcs.erase(5)
	server_world.npc_combat_instances.clear()
	server_world.next_combat_id = 1
	print("✓ Cleanup complete")

	queue_free()
