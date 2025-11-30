extends Node
## Client Launcher - Determines whether to show updater or go straight to game

func _ready():
	# If running as exported build (not editor), show updater
	if OS.has_feature("standalone"):
		print("[Launcher] Running as standalone - loading updater")
		get_tree().change_scene_to_file("res://source/client/updater/game_updater.tscn")
	else:
		# Running in editor - go straight to login for testing
		print("[Launcher] Running in editor - skipping updater")
		get_tree().change_scene_to_file("res://source/client/ui/login_screen.tscn")
