class_name RealtimeBattleLauncher
extends Node
## Realtime Battle Launcher - Creates and manages battle instances on client
## Transitions the main game screen to show the battle instance

var active_battle_scene = null  # RealtimeBattleScene
var active_controller = null  # RealtimeBattleController
var game_world: Node = null  # Reference to game world
var hidden_world_nodes: Array[Node] = []  # Nodes hidden during battle

## Preloads
var RealtimeBattleSceneScript = preload("res://scripts/realtime_battle/realtime_battle_scene.gd")
var RealtimeBattleControllerScript = preload("res://scripts/realtime_battle/realtime_battle_controller.gd")

func initialize(world_node: Node) -> void:
	"""Set the game world reference"""
	game_world = world_node
	print("[RT_LAUNCHER] Initialized with world: ", world_node.name if world_node else "NULL")

func start_battle(battle_data: Dictionary) -> void:
	"""Transition main screen to show battle instance"""
	if active_battle_scene:
		print("[RT_LAUNCHER] ERROR: Battle already active!")
		return

	if not game_world:
		print("[RT_LAUNCHER] ERROR: Game world not initialized!")
		return

	# Hide all game world children (keep track to restore later)
	hidden_world_nodes.clear()
	for child in game_world.get_children():
		if child.visible:
			child.visible = false
			hidden_world_nodes.append(child)

	# Create battle scene and add to game world
	active_battle_scene = Node2D.new()
	active_battle_scene.set_script(RealtimeBattleSceneScript)
	active_battle_scene.name = "RealtimeBattle"
	game_world.add_child(active_battle_scene)

	# Tell battle scene to use the current map as arena background
	active_battle_scene.set_meta("use_current_map", true)
	active_battle_scene.set_meta("parent_node", game_world)

	# Create controller for input handling
	active_controller = Node.new()
	active_controller.set_script(RealtimeBattleControllerScript)
	active_controller.name = "RealtimeBattleController"
	add_child(active_controller)

	# Get network service
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	var rt_service = null
	if server_conn:
		rt_service = server_conn.get_node_or_null("RealtimeCombatService")

	# Initialize and connect
	active_controller.initialize(active_battle_scene, rt_service)
	active_controller.on_battle_start(battle_data)

	# Register controller with network service
	if server_conn:
		server_conn.set_meta("active_realtime_battle_controller", active_controller)

	# Connect end signal
	active_battle_scene.battle_ended.connect(_on_battle_ended)

	print("[RT_LAUNCHER] Battle started - transitioned to battle instance")

func end_battle() -> void:
	"""Clean up battle and restore main game screen"""
	# Clean up battle nodes
	if active_controller:
		active_controller.queue_free()
		active_controller = null

	if active_battle_scene:
		active_battle_scene.queue_free()
		active_battle_scene = null

	# Restore hidden world nodes
	for node in hidden_world_nodes:
		if is_instance_valid(node):
			node.visible = true
	hidden_world_nodes.clear()

	# Unregister from network
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if server_conn and server_conn.has_meta("active_realtime_battle_controller"):
		server_conn.remove_meta("active_realtime_battle_controller")

	print("[RT_LAUNCHER] Battle ended - returned to main screen")

func _on_battle_ended(result: String, rewards: Dictionary) -> void:
	"""Handle battle end signal"""
	print("[RT_LAUNCHER] Battle result: %s" % result)
	# Delay cleanup to allow animations to finish
	await get_tree().create_timer(1.0).timeout
	end_battle()

func is_in_battle() -> bool:
	"""Check if a battle is currently active"""
	return active_battle_scene != null
