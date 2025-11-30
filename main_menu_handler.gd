extends Node

# Global main menu handler - add this as an autoload

func _ready():
	# Make sure this node processes input
	set_process_input(true)

func _input(event):
	if event.is_action_pressed("main_menu"):
		return_to_main_menu()

func return_to_main_menu():
	print("Returning to main menu...")
	# Reset camera and viewport before changing scene
	if get_viewport().get_camera_2d():
		get_viewport().get_camera_2d().force_update_scroll()
	# Change to the gateway scene (main menu)
	get_tree().change_scene_to_file("res://source/client/gateway/gateway.tscn")
