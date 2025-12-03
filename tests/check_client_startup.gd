extends SceneTree

func _init():
	print("Starting Client Startup Check...")
	var main_scene_path = "res://source/client/client_main.tscn"
	if ResourceLoader.exists(main_scene_path):
		var main_scene = load(main_scene_path)
		if main_scene:
			print("Client Main Scene loaded successfully.")
			var instance = main_scene.instantiate()
			root.add_child(instance)
			print("Client Main Scene instantiated and added to tree.")

			# Wait a frame for _ready to run
			await process_frame

			# Check if Gateway is present
			var ui_layer = instance.get_node_or_null("UILayer")
			if ui_layer:
				print("UILayer found.")
				var gateway = ui_layer.get_node_or_null("Gateway")
				if gateway:
					print("Gateway node found.")
					if gateway.visible:
						print("Gateway is visible.")
					else:
						print("WARNING: Gateway is NOT visible.")
				else:
					print("ERROR: Gateway node NOT found in UILayer.")
			else:
				print("ERROR: UILayer NOT found.")
		else:
			print("ERROR: Failed to load packed scene.")
	else:
		print("ERROR: Resource does not exist: " + main_scene_path)

	print("Check complete.")
	quit()