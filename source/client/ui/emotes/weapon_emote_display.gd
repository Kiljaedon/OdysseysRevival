extends Control
## Weapon Emote Display - Shows popup messages when weapon is toggled
## Displays "You ready your weapon!" or "You sheathe your weapon!" with icon

signal emote_finished

# Configuration
const DISPLAY_DURATION: float = 2.0
const FADE_DURATION: float = 0.3
const POPUP_OFFSET: Vector2 = Vector2(0, -100)  # Above character

# Combat emote icon (sword icon)
var combat_icon: Texture2D

# UI elements
var panel: PanelContainer
var hbox: HBoxContainer
var icon_rect: TextureRect
var message_label: Label

# Animation state
var display_timer: float = 0.0
var fade_timer: float = 0.0
var is_displaying: bool = false
var is_fading: bool = false


func _ready():
	# Load combat emote icon
	combat_icon = load("res://assets/gui/emotes/emote_combat.png")

	# Create UI structure
	_create_ui()

	# Start hidden
	modulate.a = 0.0
	visible = false


func _create_ui():
	# Create panel container for background
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(panel)

	# Create horizontal box for icon + text
	hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Create icon
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon_rect)

	# Create label
	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(message_label)


func _process(delta: float):
	if not is_displaying:
		return

	# Handle display timer
	if not is_fading:
		display_timer -= delta
		if display_timer <= 0.0:
			# Start fading out
			is_fading = true
			fade_timer = FADE_DURATION

	# Handle fade out
	if is_fading:
		fade_timer -= delta
		var alpha = fade_timer / FADE_DURATION
		modulate.a = alpha

		if fade_timer <= 0.0:
			# Finished fading
			is_displaying = false
			is_fading = false
			visible = false
			emote_finished.emit()


func show_weapon_ready():
	"""Show 'You ready your weapon!' message with sword icon"""
	_show_message("You ready your weapon!", combat_icon)


func show_weapon_sheathed():
	"""Show 'You sheathe your weapon!' message with sheath icon"""
	# Use combat icon for both (could use different icon if available)
	_show_message("You sheathe your weapon!", combat_icon)


func _show_message(text: String, icon: Texture2D):
	"""Internal function to display a message with icon"""
	# Set content
	message_label.text = text
	icon_rect.texture = icon

	# Reset state
	display_timer = DISPLAY_DURATION
	fade_timer = 0.0
	is_displaying = true
	is_fading = false

	# Show with full opacity
	visible = true
	modulate.a = 1.0

	# Position above character (set by parent)
	# Parent should set global_position to character position + POPUP_OFFSET
