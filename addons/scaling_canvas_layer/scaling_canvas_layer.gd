# Copyright © 2021 Nicholas Yang and contributors - MIT License
# See `LICENSE.md` included in the source distribution for details.

extends CanvasLayer

# The shrink ratio to add on top of scaled content and UI.
@export var stretch_shrink: float = 1.0

# Toggles content scaling on/off.
@export var scale_content: bool = true

# Ideal resolution for the content.
@export var content_desired_resolution: Vector2 = Vector2(0, 0)

# Path to the Camera2D that will be used for content scaling.
@export var camera_path: NodePath

# Toggles UI scaling on/off.
@export var scale_ui: bool = true

# Ideal resolution for the UI.
@export var ui_desired_resolution: Vector2 = Vector2(0, 0)

# Factor that determines how much to scale UI by width and how much by height
# (0.0 = width, 1.0 = height).
@export_range(0.0, 1.0) var ui_width_height_factor: float = 0.5

# Reference to camera object.
var _camera: Camera2D = null


func _ready():
	# Check for a valid camera.
	if camera_path != null and has_node(camera_path):
		_camera = get_node(camera_path)
		if not _camera is Camera2D:
			_camera = null

	if not _camera == null:
		# Camera must be active in order for results to be visible.
		_camera.current = true
	else:
		# Cannot scale content if there is no camera assigned.
		scale_content = false

	# If the desired resolution is not set, refer to Project Settings > Display > Window.
	if content_desired_resolution == Vector2(0, 0):
		content_desired_resolution = Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height")
		)
	if ui_desired_resolution == Vector2(0, 0):
		ui_desired_resolution = Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height")
		)

	# Initial call and setup.
	_do_scaling()
	get_viewport().size_changed.connect(_do_scaling)


func _do_scaling() -> void:
	var window_size := get_viewport().get_visible_rect().size

	if scale_content or scale_ui:
		# Note: set_screen_stretch is deprecated in Godot 4.x
		# Stretch settings are now handled in project settings
		pass

	if scale_content:
		# We want a "Mode: expand" effect (basically "Keep Width" combined with "Keep Height")
		# to prevent black bars from appearing. If the window is taller than the desired aspect,
		# we scale everything according to the width (i.e., "Keep Width", or expand vertically).
		# If the window is wider, we scale according to the height (i.e., "Keep Height", or expand
		# horizontally). Afterwards, to remove content reveal, we scale the result by a correction
		# factor, the percent difference between the current and desired aspects.
		var desired_aspect := content_desired_resolution.aspect()
		var current_aspect := window_size.aspect()
		var black_bars_scale := 1.0
		var content_reveal_scale := 1.0

		# Window is taller than the desired resolution.
		if current_aspect < desired_aspect:
			black_bars_scale = content_desired_resolution.x / window_size.x
			content_reveal_scale = current_aspect / desired_aspect

		# Window is wider than the desired resolution.
		else:
			black_bars_scale = content_desired_resolution.y / window_size.y
			content_reveal_scale = desired_aspect / current_aspect

		# Scale by adjusting zoom, which allows pixel fractions and thus cannot be pixel-pefect.
		if not _camera == null:
			# Calculate the scaling factor. When it is less than 1, the camera zooms in.
			# When it is greater than 1, the camera zooms out.
			var content_scale := black_bars_scale * content_reveal_scale

			_camera.zoom = Vector2(1, 1) * content_scale

	if scale_ui:
		# Get weighted ratios of the current window size to the desired resolution.
		var width_ratio := window_size.x / ui_desired_resolution.x
		var height_ratio := window_size.y / ui_desired_resolution.y
		var width_weight := 1.0 - ui_width_height_factor
		var height_weight := ui_width_height_factor

		# Calculate the amount to scale the UI (i.e., this CanvasLayer's scale).
		var ui_scale := (width_ratio * width_weight) + (height_ratio * height_weight)

		scale = Vector2(1, 1) * ui_scale
