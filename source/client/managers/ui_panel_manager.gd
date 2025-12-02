class_name UIPanelManager
extends Node

## Phase 3: UI System Manager - Manages all draggable panels and UI creation
## Handles: Panel factory, UI layout, draggable panel management, content creation

const DraggablePanel = preload("res://source/client/ui/common/draggable_panel.gd")

## State tracking
var draggable_panels: Array[Panel] = []

## Game references (dependency injection)
var game_world: Node2D
var map_manager: Node  # For map operations
var character_sprite_manager: Node  # For sprite loading
var ui_layout_manager: Node  # For layout persistence

## UI element references (populated during panel creation)
var map_dropdown: OptionButton
var map_info: Label
var class_dropdown: OptionButton
var animation_dropdown: OptionButton
var direction_dropdown: OptionButton
var frame_info: Label

## ============================================================================
## INITIALIZATION
## ============================================================================

func initialize(world: Node2D, char_mgr: Node, layout_mgr: Node) -> void:
	"""Initialize panel manager with dependency references.

	Args:
		world: GameWorld node for sprite loading and rendering
		char_mgr: CharacterSpriteManager for sprite operations
		layout_mgr: UILayoutManager for layout persistence
	"""
	game_world = world
	character_sprite_manager = char_mgr
	ui_layout_manager = layout_mgr

	print("[UIPanelManager] Initialized with dependencies")

## ============================================================================
## PANEL CREATION (Factory Pattern)
## ============================================================================

func create_draggable_ui() -> void:
	"""Create all draggable UI panels for development client."""
	print("[UIPanelManager] Creating draggable UI system...")

	# Clear existing panels
	var dev_ui = game_world.get_parent().get_node_or_null("DevUI")
	if dev_ui:
		for child in dev_ui.get_children():
			child.queue_free()

	# Create Game Screen panel (main gameplay window)
	var game_panel = create_panel("Game Screen", Vector2(50, 50), Vector2(800, 600))

	create_game_screen_content(game_panel)

	print("[UIPanelManager] ✓ Draggable UI created with %d panels" % draggable_panels.size())

func create_panel(title: String, pos: Vector2, panel_size: Vector2) -> Panel:
	"""Generic panel factory - creates a draggable, resizable panel.

	Args:
		title: Panel window title
		pos: Initial position
		panel_size: Initial size

	Returns:
		Created Panel with DraggablePanel behavior
	"""
	var panel = Panel.new()
	panel.set_script(DraggablePanel)

	# Add to DevUI CanvasLayer
	var dev_ui = game_world.get_parent().get_node_or_null("DevUI")
	if dev_ui:
		dev_ui.add_child(panel)

	# Set properties after adding to scene
	panel.panel_title = title
	panel.position = pos
	panel.size = panel_size

	# Connect signals
	panel.panel_locked.connect(_on_panel_locked)
	panel.panel_unlocked.connect(_on_panel_unlocked)

	draggable_panels.append(panel)
	return panel

## ============================================================================
## PANEL CONTENT CREATION
## ============================================================================

func create_game_screen_content(parent: Panel) -> void:
	"""Create game screen viewport container for displaying the game world.

	Embeds GameWorld into a SubViewport so it can be displayed within the panel.
	"""
	# Create a SubViewport to contain the game world inside the panel
	var subviewport_container = SubViewportContainer.new()
	subviewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	subviewport_container.offset_left = 5
	subviewport_container.offset_right = -5
	subviewport_container.offset_top = 35  # Below title bar
	subviewport_container.offset_bottom = -5
	subviewport_container.stretch = true
	parent.add_child(subviewport_container)

	var subviewport = SubViewport.new()
	subviewport.name = "GameSubViewport"
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	subviewport.handle_input_locally = true
	subviewport.gui_disable_input = false
	# Set beige/cream background to match Kenny UI theme
	subviewport.transparent_bg = false
	# Don't use global clear color - it affects ALL viewports
	# Instead, we rely on a background layer in GameWorld
	subviewport_container.add_child(subviewport)

	# Ensure SubViewport has a valid size (will be overridden by stretch)
	subviewport.size = Vector2i(800, 600)

	# Move GameWorld into the SubViewport
	if game_world:
		game_world.get_parent().remove_child(game_world)
		subviewport.add_child(game_world)

		# Add a background using CanvasLayer + ColorRect for SubViewport
		var bg_layer = CanvasLayer.new()
		bg_layer.name = "ViewportBackgroundLayer"
		bg_layer.layer = -100  # Behind everything
		subviewport.add_child(bg_layer)

		var bg = ColorRect.new()
		bg.name = "ViewportBackground"
		bg.color = Color(0.85, 0.75, 0.60)  # Beige/cream to match Kenny UI
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_layer.add_child(bg)

		print("[UIPanelManager] GameWorld moved to SubViewport")
		print("[UIPanelManager] SubViewport children: %s" % [subviewport.get_children()])
		print("[UIPanelManager] GameWorld parent: %s" % game_world.get_parent())
		print("[UIPanelManager] SubViewport size: %s" % subviewport.size)

func create_map_selector_content(parent: Panel) -> void:
	"""Create map selector UI with dropdown and load button.

	Populates map dropdown from available TMX files.
	"""
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 40)
	vbox.size = Vector2(230, 130)
	parent.add_child(vbox)

	map_dropdown = OptionButton.new()
	vbox.add_child(map_dropdown)

	var load_button = Button.new()
	load_button.text = "Load Map"
	load_button.pressed.connect(_on_load_map_pressed)
	vbox.add_child(load_button)

	map_info = Label.new()
	map_info.text = "No map loaded"
	map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(map_info)

	print("[UIPanelManager] Map selector created")

func create_character_tester_content(parent: Panel) -> void:
	"""Create character testing panel with animation controls.

	Includes:
	- Character class selector
	- Animation and direction dropdowns
	- Play/Pause/Stop buttons
	- Frame counter
	- Map selector
	- Development tools section
	- Layout controls
	"""
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 40)
	vbox.size = Vector2(260, 550)
	parent.add_child(vbox)

	# === CHARACTER SECTION ===
	var char_label = Label.new()
	char_label.text = "CHARACTER"
	char_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(char_label)

	class_dropdown = OptionButton.new()
	vbox.add_child(class_dropdown)

	animation_dropdown = OptionButton.new()
	vbox.add_child(animation_dropdown)

	direction_dropdown = OptionButton.new()
	vbox.add_child(direction_dropdown)

	var controls_hbox = HBoxContainer.new()
	vbox.add_child(controls_hbox)

	var play_button = Button.new()
	play_button.text = "Play"
	play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_hbox.add_child(play_button)

	var pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_hbox.add_child(pause_button)

	var stop_button = Button.new()
	stop_button.text = "Stop"
	stop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_hbox.add_child(stop_button)

	frame_info = Label.new()
	frame_info.text = "Frame: 0/0"
	vbox.add_child(frame_info)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# === MAP SECTION ===
	var map_label = Label.new()
	map_label.text = "MAP"
	map_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(map_label)

	map_dropdown = OptionButton.new()
	vbox.add_child(map_dropdown)

	var load_button = Button.new()
	load_button.text = "Load Map"
	load_button.pressed.connect(_on_load_map_pressed)
	vbox.add_child(load_button)

	map_info = Label.new()
	map_info.text = "No map loaded"
	map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(map_info)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# === TOOLS SECTION ===
	var tools_label = Label.new()
	tools_label.text = "DEVELOPMENT TOOLS"
	tools_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(tools_label)

	var sprite_button = Button.new()
	sprite_button.text = "Sprite Creator"
	sprite_button.pressed.connect(_on_sprite_creator_pressed)
	vbox.add_child(sprite_button)

	var map_editor_button = Button.new()
	map_editor_button.text = "Map Editor (Tiled)"
	map_editor_button.pressed.connect(_on_map_editor_pressed)
	vbox.add_child(map_editor_button)

	var sep3 = HSeparator.new()
	vbox.add_child(sep3)

	# === LAYOUT SECTION ===
	var layout_label = Label.new()
	layout_label.text = "LAYOUT"
	layout_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(layout_label)

	var save_button = Button.new()
	save_button.text = "Save Panel Layout"
	save_button.pressed.connect(_on_save_layout_pressed)
	vbox.add_child(save_button)

	var reset_button = Button.new()
	reset_button.text = "Reset Panel Layout"
	reset_button.pressed.connect(_on_reset_layout_pressed)
	vbox.add_child(reset_button)

	print("[UIPanelManager] Character tester panel created")

func create_dev_tools_content(parent: Panel) -> void:
	"""Create development tools panel with external tool launchers.

	Includes:
	- Sprite Creator
	- Map Editor (Tiled)
	- Art Studio
	"""
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 40)
	vbox.size = Vector2(230, 100)
	parent.add_child(vbox)

	var sprite_button = Button.new()
	sprite_button.text = "Sprite Creator"
	sprite_button.pressed.connect(_on_sprite_creator_pressed)
	vbox.add_child(sprite_button)

	var map_button = Button.new()
	map_button.text = "Map Editor"
	map_button.pressed.connect(_on_map_editor_pressed)
	vbox.add_child(map_button)

	var art_button = Button.new()
	art_button.text = "Art Studio"
	art_button.pressed.connect(_on_art_studio_pressed)
	vbox.add_child(art_button)

	print("[UIPanelManager] Dev tools panel created")

func create_controls_reference_content(parent: Panel) -> void:
	"""Create controls reference panel with help text and layout controls."""
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 40)
	vbox.size = Vector2(230, 200)
	parent.add_child(vbox)

	# Controls label
	var label = Label.new()
	label.text = "CONTROLS:\nWASD: Move Character\nSPACE: Attack Animation\nENTER: Open Chat\n- / +: Zoom Out / In\nMouse Wheel: Zoom\nESC: Return to Menu\n\nUI PANELS:\nDrag panels by title bar\nResize from bottom-right\nClick lock to lock panels"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(label)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Layout buttons
	var save_button = Button.new()
	save_button.text = "Save Layout"
	save_button.pressed.connect(_on_save_layout_pressed)
	vbox.add_child(save_button)

	var reset_button = Button.new()
	reset_button.text = "Reset Layout"
	reset_button.pressed.connect(_on_reset_layout_pressed)
	vbox.add_child(reset_button)

	print("[UIPanelManager] Controls reference panel created")

func create_sprite_loader_content(parent: Panel) -> void:
	"""Create sprite loader panel for loading characters from sprite creator.

	Allows selecting and loading character animations created in the sprite maker.
	"""
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 40)
	vbox.size = Vector2(280, 350)
	parent.add_child(vbox)

	# Title label
	var title = Label.new()
	title.text = "Load Character from Sprite Editor"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	# Character dropdown
	var character_dropdown = OptionButton.new()
	character_dropdown.add_item("Select Character...")
	vbox.add_child(character_dropdown)

	# Load character data for dropdown
	var chars_dir = DirAccess.open("res://characters/")
	if chars_dir:
		chars_dir.list_dir_begin()
		var file_name = chars_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var char_name = file_name.get_basename()
				character_dropdown.add_item(char_name)
			file_name = chars_dir.get_next()
		chars_dir.list_dir_end()

	# Load button
	var load_char_button = Button.new()
	load_char_button.text = "Load Selected Character"
	load_char_button.pressed.connect(_on_load_character_from_dropdown.bind(character_dropdown))
	vbox.add_child(load_char_button)

	# Separator
	var separator = HSeparator.new()
	vbox.add_child(separator)

	# Open sprite editor button
	var open_editor_button = Button.new()
	open_editor_button.text = "Open Sprite Creator"
	open_editor_button.pressed.connect(_on_sprite_creator_pressed)
	vbox.add_child(open_editor_button)

	# Info label
	var info_label = Label.new()
	info_label.text = "Use Sprite Creator to create/edit character animations, then load them here."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(260, 60)
	vbox.add_child(info_label)

	print("[UIPanelManager] Sprite loader panel created")

## ============================================================================
## PANEL EVENT HANDLERS
## ============================================================================

func _on_panel_locked(panel: Panel) -> void:
	"""Signal handler when a panel is locked."""
	print("[UIPanelManager] Panel locked: ", panel.name)

func _on_panel_unlocked(panel: Panel) -> void:
	"""Signal handler when a panel is unlocked."""
	print("[UIPanelManager] Panel unlocked: ", panel.name)

func _on_load_map_pressed() -> void:
	"""Signal handler for map load button - emits signal to parent controller."""
	map_load_requested.emit()

func _on_sprite_creator_pressed() -> void:
	"""Signal handler for sprite creator button - emits signal to parent controller."""
	sprite_creator_requested.emit()

func _on_map_editor_pressed() -> void:
	"""Signal handler for map editor button - emits signal to parent controller."""
	map_editor_requested.emit()

func _on_art_studio_pressed() -> void:
	"""Signal handler for art studio button - emits signal to parent controller."""
	art_studio_requested.emit()

func _on_save_layout_pressed() -> void:
	"""Signal handler for save layout button."""
	if ui_layout_manager:
		ui_layout_manager.save_ui_layout()

func _on_reset_layout_pressed() -> void:
	"""Signal handler for reset layout button."""
	if ui_layout_manager:
		ui_layout_manager.reset_ui_layout()

func _on_load_character_from_dropdown(dropdown: OptionButton) -> void:
	"""Signal handler when user selects a character from dropdown.

	Args:
		dropdown: The OptionButton containing selected character
	"""
	var selected_index = dropdown.selected
	if selected_index > 0:  # Skip "Select Character..." option
		var character_name = dropdown.get_item_text(selected_index)
		character_selected.emit(character_name)

## ============================================================================
## SIGNALS (for parent controller communication)
## ============================================================================

signal map_load_requested()
signal sprite_creator_requested()
signal map_editor_requested()
signal art_studio_requested()
signal character_selected(character_name: String)
