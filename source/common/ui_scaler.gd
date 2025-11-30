extends Node
## UI Scaler - Dynamically adjusts UI elements to fit the window and keeps them centered

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	scale_ui_elements()
	get_window().size_changed.connect(_on_window_resized)

func _on_window_resized() -> void:
	await get_tree().process_frame
	scale_ui_elements()

func scale_ui_elements() -> void:
	var window_size = Vector2(get_window().size)
	var base_size = Vector2(960, 540)
	var scale_x = window_size.x / base_size.x
	var scale_y = window_size.y / base_size.y
	var scale_factor = min(scale_x, scale_y)
	print("Window size: ", window_size, " Scale factor: ", scale_factor)
	print("UI Scaler: Gateway uses built-in anchoring under CanvasLayer, manual scaling disabled")
	_center_other_ui_elements(scale_factor)

func _center_other_ui_elements(scale_factor: float) -> void:
	pass
