extends Node
## Window manager - handles resizable window with centered UI

# Reference to gateway node, registered by client_main when ready
var _gateway: Control = null

func _ready() -> void:
	# Query screen size
	var screen_size = DisplayServer.screen_get_size()

	# Define window dimensions - 80% of screen or default size
	var default_width = 1280
	var default_height = 720
	var target_width = min(int(screen_size.x * 0.8), default_width)
	var target_height = min(int(screen_size.y * 0.8), default_height)

	# Define minimum and maximum bounds
	var min_size = Vector2i(960, 540)
	var max_size = Vector2i(
		screen_size.x - 100,
		screen_size.y - 100
	)

	# Set window to target size
	var window_size = Vector2i(
		clamp(target_width, min_size.x, max_size.x),
		clamp(target_height, min_size.y, max_size.y)
	)

	get_window().size = window_size

	# Set minimum window size so users can't shrink below UI baseline
	get_window().min_size = min_size

	# Center window on screen
	get_window().move_to_center()

	# Enable window controls for resizable, windowed mode
	get_window().mode = Window.MODE_WINDOWED
	get_window().unresizable = false
	get_window().borderless = false

	# Connect to window resize signal
	get_window().size_changed.connect(_on_window_resized)

	print("Window initialized: size=", get_window().size, " mode=WINDOWED resizable=true")

	# Wait a few frames then fix UI positioning
	await get_tree().process_frame
	await get_tree().process_frame
	fix_ui_positioning()

func _on_window_resized() -> void:
	# Recenter UI when window is resized
	await get_tree().process_frame
	fix_ui_positioning()

## Register the gateway node for UI positioning (called by client_main when ready)
func register_gateway(gateway: Control) -> void:
	_gateway = gateway
	fix_ui_positioning()

func fix_ui_positioning() -> void:
	if _gateway and _gateway is Control:
		# Set gateway to fill the entire window but allow proper centering
		_gateway.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		# Let the UI scaler handle the actual positioning and scaling
		# This ensures the UI stays centered when window is resized
		print("Gateway positioned for resizable window: size=", get_window().size)
