extends Control
## Quick Test Client Launcher
## Auto-connects to localhost server and goes straight to login

func _ready():
	print("=== TEST CLIENT - AUTO-CONNECTING TO SERVER ===")
	
	# Small delay to let everything initialize
	await get_tree().create_timer(0.5).timeout
	
	# Go directly to login screen
	get_tree().change_scene_to_file("res://source/client/ui/login_screen.tscn")
