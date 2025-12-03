@tool
extends SceneTree

func _init():
	print("Widening tilesets (Attempt 2 - Load from File)...")
	
	# Use global paths to bypass ResourceLoader import issues
	var part1_src = ProjectSettings.globalize_path("res://assets-odyssey/tiles_part1.png")
	var part1_dst = ProjectSettings.globalize_path("res://assets-odyssey/tiles_part1_wide.png")
	
	var part2_src = ProjectSettings.globalize_path("res://assets-odyssey/tiles_part2.png")
	var part2_dst = ProjectSettings.globalize_path("res://assets-odyssey/tiles_part2_wide.png")
	
	widen_image(part1_src, part1_dst)
	widen_image(part2_src, part2_dst)
	
	quit()

func widen_image(src_path: String, dst_path: String):
	if not FileAccess.file_exists(src_path):
		print("Error: Source file not found: " + src_path)
		return

	var image = Image.load_from_file(src_path)
	if not image:
		print("Error: Failed to load image from " + src_path)
		return
		
	var tile_size = 32
	var src_cols = 7
	var dst_cols = 32
	
	var total_tiles = (image.get_width() / tile_size) * (image.get_height() / tile_size)
	var dst_rows = ceil(float(total_tiles) / float(dst_cols))
	
	var dst_width = dst_cols * tile_size
	var dst_height = int(dst_rows * tile_size)
	
	print("Converting %s:" % src_path)
	print("  Src: %dx%d (%d tiles)" % [image.get_width(), image.get_height(), total_tiles])
	print("  Dst: %dx%d (%d cols x %d rows)" % [dst_width, dst_height, dst_cols, dst_rows])
	
	var dst_image = Image.create(dst_width, dst_height, false, image.get_format())
	
	for i in range(total_tiles):
		var src_x = (i % src_cols) * tile_size
		var src_y = (i / src_cols) * tile_size
		
		var dst_x = (i % dst_cols) * tile_size
		var dst_y = (i / dst_cols) * tile_size
		
		# Blit tile region
		var region = Rect2i(src_x, src_y, tile_size, tile_size)
		dst_image.blit_rect(image, region, Vector2i(dst_x, dst_y))
		
	var err = dst_image.save_png(dst_path)
	if err == OK:
		print("  Saved to " + dst_path)
	else:
		print("  Error saving: " + str(err))