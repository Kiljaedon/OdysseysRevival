class_name RealtimeBattleLauncher
extends Node
## Realtime Battle Launcher - Creates and manages battle instances on client
## Creates a battle window overlay using the current map as the arena background

var active_battle_scene = null  # RealtimeBattleScene
var active_controller = null  # RealtimeBattleController
var battle_canvas_layer: CanvasLayer = null  # Overlay layer
var battle_panel: Panel = null  # The battle window
var battle_viewport_container: SubViewportContainer = null
var battle_viewport: SubViewport = null
var parent_node: Node = null  # Reference to game world
var game_was_paused: bool = false  # Track if we paused the game

## Battle window size
const BATTLE_WINDOW_WIDTH: int = 900
const BATTLE_WINDOW_HEIGHT: int = 700

## Preloads
var RealtimeBattleSceneScript = preload("res://scripts/realtime_battle/realtime_battle_scene.gd")
var RealtimeBattleControllerScript = preload("res://scripts/realtime_battle/realtime_battle_controller.gd")

func initialize(battle_parent: Node) -> void:
	"""Set the parent node reference"""
	parent_node = battle_parent
	print("[RT_LAUNCHER] Initialized with parent: ", battle_parent.name if battle_parent else "NULL")

func start_battle(battle_data: Dictionary) -> void:
	"""Launch a new realtime battle in a window overlay, using current map as arena"""
	if active_battle_scene:
		print("[RT_LAUNCHER] ERROR: Battle already active!")
		return

	# Freeze the game tree (but battle will run in its own process)
	game_was_paused = get_tree().paused
	get_tree().paused = true

	# Create CanvasLayer for battle overlay
	battle_canvas_layer = CanvasLayer.new()
	battle_canvas_layer.name = "BattleOverlay"
	battle_canvas_layer.layer = 100  # Above all game UI
	battle_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS  # Run even when paused
	get_tree().root.add_child(battle_canvas_layer)

	# Semi-transparent background to show frozen game
	var dim_bg = ColorRect.new()
	dim_bg.name = "DimBackground"
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.6)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	battle_canvas_layer.add_child(dim_bg)

	# Create centered battle panel
	battle_panel = Panel.new()
	battle_panel.name = "BattlePanel"
	battle_panel.custom_minimum_size = Vector2(BATTLE_WINDOW_WIDTH, BATTLE_WINDOW_HEIGHT)
	battle_panel.size = Vector2(BATTLE_WINDOW_WIDTH, BATTLE_WINDOW_HEIGHT)
	battle_panel.set_anchors_preset(Control.PRESET_CENTER)
	battle_panel.position = Vector2(-BATTLE_WINDOW_WIDTH / 2, -BATTLE_WINDOW_HEIGHT / 2)
	battle_canvas_layer.add_child(battle_panel)

	# Style the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	panel_style.border_color = Color(0.5, 0.4, 0.3, 1.0)
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(8)
	battle_panel.add_theme_stylebox_override("panel", panel_style)

	# Title bar
	var title_bar = Panel.new()
	title_bar.name = "TitleBar"
	title_bar.size = Vector2(BATTLE_WINDOW_WIDTH - 8, 28)
	title_bar.position = Vector2(4, 4)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.25, 0.2, 0.15, 1.0)
	title_style.set_corner_radius_all(4)
	title_bar.add_theme_stylebox_override("panel", title_style)
	battle_panel.add_child(title_bar)

	var title_label = Label.new()
	title_label.text = "BATTLE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.add_theme_font_size_override("font_size", 14)
	title_bar.add_child(title_label)

	# SubViewportContainer for battle
	battle_viewport_container = SubViewportContainer.new()
	battle_viewport_container.name = "BattleViewportContainer"
	battle_viewport_container.position = Vector2(4, 36)
	battle_viewport_container.size = Vector2(BATTLE_WINDOW_WIDTH - 8, BATTLE_WINDOW_HEIGHT - 40)
	battle_viewport_container.stretch = true
	battle_panel.add_child(battle_viewport_container)

	# SubViewport for battle rendering
	battle_viewport = SubViewport.new()
	battle_viewport.name = "BattleViewport"
	battle_viewport.size = Vector2i(BATTLE_WINDOW_WIDTH - 8, BATTLE_WINDOW_HEIGHT - 40)
	battle_viewport.handle_input_locally = true
	battle_viewport.gui_disable_input = false
	battle_viewport.transparent_bg = false
	battle_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	battle_viewport_container.add_child(battle_viewport)

	# Create battle scene
	active_battle_scene = Node2D.new()
	active_battle_scene.set_script(RealtimeBattleSceneScript)
	active_battle_scene.name = "RealtimeBattle"
	active_battle_scene.process_mode = Node.PROCESS_MODE_ALWAYS
	battle_viewport.add_child(active_battle_scene)

	# Tell battle scene to use the current map as arena background
	active_battle_scene.set_meta("use_current_map", true)
	active_battle_scene.set_meta("parent_node", parent_node)

	# Create controller - add to canvas layer (NOT viewport) so it receives input when paused
	# SubViewports don't propagate input events when the main tree is paused
	active_controller = Node.new()
	active_controller.set_script(RealtimeBattleControllerScript)
	active_controller.name = "RealtimeBattleController"
	active_controller.process_mode = Node.PROCESS_MODE_ALWAYS
	battle_canvas_layer.add_child(active_controller)

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

	print("[RT_LAUNCHER] Battle launched in %dx%d window (using current map as arena)" % [BATTLE_WINDOW_WIDTH, BATTLE_WINDOW_HEIGHT])

func end_battle() -> void:
	"""Clean up active battle and unfreeze game"""
	# Clean up battle nodes
	if active_controller:
		active_controller.queue_free()
		active_controller = null

	if active_battle_scene:
		active_battle_scene.queue_free()
		active_battle_scene = null

	if battle_viewport:
		battle_viewport.queue_free()
		battle_viewport = null

	if battle_viewport_container:
		battle_viewport_container.queue_free()
		battle_viewport_container = null

	if battle_panel:
		battle_panel.queue_free()
		battle_panel = null

	if battle_canvas_layer:
		battle_canvas_layer.queue_free()
		battle_canvas_layer = null

	# Unfreeze the game
	get_tree().paused = game_was_paused

	# Unregister from network
	var server_conn = get_tree().root.get_node_or_null("ServerConnection")
	if server_conn and server_conn.has_meta("active_realtime_battle_controller"):
		server_conn.remove_meta("active_realtime_battle_controller")

	print("[RT_LAUNCHER] Battle ended - game unfrozen")

func _on_battle_ended(result: String, rewards: Dictionary) -> void:
	"""Handle battle end signal"""
	print("[RT_LAUNCHER] Battle result: %s" % result)
	# Delay cleanup to allow animations to finish
	await get_tree().create_timer(1.0).timeout
	end_battle()

func is_in_battle() -> bool:
	"""Check if a battle is currently active"""
	return active_battle_scene != null
