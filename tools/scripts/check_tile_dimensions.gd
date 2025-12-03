@tool
extends SceneTree

func _init():
	var tex1 = load("res://assets-odyssey/tiles_part1.png")
	if tex1:
		print("Tiles Part 1 Size: %s" % tex1.get_size())
		print("Tiles Part 1 Columns (32px): %d" % (tex1.get_width() / 32))
	else:
		print("Failed to load tiles_part1.png")

	var tex2 = load("res://assets-odyssey/tiles_part2.png")
	if tex2:
		print("Tiles Part 2 Size: %s" % tex2.get_size())
		print("Tiles Part 2 Columns (32px): %d" % (tex2.get_width() / 32))
	else:
		print("Failed to load tiles_part2.png")
	
	quit()
