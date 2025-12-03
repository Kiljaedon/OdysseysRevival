@tool
extends SceneTree

func _init():
	print("Checking ORIGINAL tileset dimensions...")
	var img = Image.load_from_file("res://assets-odyssey/tiles_part1.png")
	if img:
		print("Original Image Size: %s" % img.get_size())
	else:
		print("Error: Could not load tiles_part1.png")
	quit()
