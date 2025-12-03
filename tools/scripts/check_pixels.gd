@tool
extends SceneTree

func _init():
	print("Checking pixel data of wide tileset...")
	var img = Image.load_from_file("res://assets-odyssey/tiles_part1_wide.png")
	if not img:
		print("Error: Could not load image")
		quit()
		return
		
	print("Image Size: %s" % img.get_size())
	print("Format: %d" % img.get_format())
	
	var has_content = false
	var checks = 0
	
	# Check first 100 pixels
	for y in range(32):
		for x in range(32):
			var color = img.get_pixel(x, y)
			checks += 1
			if color.a > 0:
				print("Found pixel at (%d, %d): %s" % [x, y, color])
				has_content = true
				break
		if has_content: break
		
	if not has_content:
		print("WARNING: First 32x32 block appears to be empty/transparent!")
		
		# Check a random spot in middle
		var mid_x = 100
		var mid_y = 100
		var color = img.get_pixel(mid_x, mid_y)
		print("Pixel at (%d, %d): %s" % [mid_x, mid_y, color])
	else:
		print("Image appears to have content.")
		
	quit()
