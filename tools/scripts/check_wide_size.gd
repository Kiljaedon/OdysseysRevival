@tool
extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets-odyssey/tiles_part1_wide.png")
	if img:
		print("Wide Image Size: %s" % img.get_size())
	else:
		print("Failed to load wide image")
	quit()
