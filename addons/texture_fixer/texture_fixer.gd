@tool
extends EditorScript

## Texture Fixer Tool
## Converts black backgrounds to transparent and fixes seams
## Run from: Tools → Run Script

func _run():
	print("=== TEXTURE FIXER TOOL ===")

	# Fix tiles
	fix_texture("res://assets-odyssey/tiles.png", "res://assets-odyssey/tiles_fixed.png")

	# Fix sprites
	fix_texture("res://assets-odyssey/sprites.png", "res://assets-odyssey/sprites_fixed.png")

	print("=== COMPLETE ===")
	print("Textures fixed! Replace original files with _fixed versions")

func fix_texture(input_path: String, output_path: String):
	print("\nProcessing: ", input_path)

	var img = Image.load_from_file(input_path)
	if not img:
		print("ERROR: Could not load ", input_path)
		return

	var width = img.get_width()
	var height = img.get_height()
	print("Size: ", width, "x", height)

	# Convert format if needed
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var black_converted = 0
	var seams_fixed = 0

	# Process pixels
	for y in range(height):
		for x in range(width):
			var color = img.get_pixel(x, y)

			# Convert black to transparent
			if color.r < 0.04 and color.g < 0.04 and color.b < 0.04:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				black_converted += 1
			# Fix semi-transparent pixels (seams)
			elif color.a > 0 and color.a < 1.0:
				if color.a < 0.5:
					# Make fully transparent
					img.set_pixel(x, y, Color(0, 0, 0, 0))
				else:
					# Make fully opaque
					img.set_pixel(x, y, Color(color.r, color.g, color.b, 1.0))
				seams_fixed += 1

		# Progress
		if y % 1000 == 0:
			print("  ", y, "/", height, " rows...")

	print("Black pixels converted: ", black_converted)
	print("Semi-transparent pixels fixed: ", seams_fixed)
	print("Saving: ", output_path)

	img.save_png(output_path)
	print("Saved!")