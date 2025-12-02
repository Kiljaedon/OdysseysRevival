extends Control

func _ready():
	# Print all the display info we can get
	print("=== DISPLAY DIAGNOSTICS ===")
	print("Window size: ", get_window().size)
	print("Window position: ", get_window().position)
	print("Screen size: ", DisplayServer.screen_get_size())
	print("Screen scale: ", DisplayServer.screen_get_scale())
	print("Viewport size: ", get_viewport().get_visible_rect().size)
	print("Control size: ", size)
	print("Control position: ", position)
	print("DPI: ", DisplayServer.screen_get_dpi())
	print("Window mode: ", DisplayServer.window_get_mode())
	print("=============================")

	# Force window to be specific size and position
	await get_tree().process_frame
	get_window().size = Vector2i(1280, 720)
	get_window().position = Vector2i(100, 100)
	get_window().grab_focus()

	print("After resize - Window size: ", get_window().size)