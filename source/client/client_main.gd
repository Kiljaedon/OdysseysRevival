extends Node


func _ready() -> void:
	# Add beige/cream background color to match Kenny UI theme
	var bg_fill = ColorRect.new()
	bg_fill.name = "BackgroundFill"
	bg_fill.color = Color(0.85, 0.75, 0.60, 1.0)  # Beige/cream to match Kenny theme
	bg_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_fill.z_index = -100  # Behind everything

	# Add to UILayer if it exists
	var ui_layer = get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(bg_fill)
		ui_layer.move_child(bg_fill, 0)  # Move to first position
		print("[ClientMain] ✓ Beige/cream background added to UILayer")
	else:
		# Fallback: add directly to root
		add_child(bg_fill)
		move_child(bg_fill, 0)
		print("[ClientMain] ✓ Beige/cream background added to root")
