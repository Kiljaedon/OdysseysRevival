@tool
extends SceneTree

func _init():
	print("Populating main_tileset.tres (7-column layout)...")
	
	var tileset_path = "res://addons/gs_mmo_tools/resources/main_tileset.tres"
	var tileset = load(tileset_path)
	if not tileset:
		print("Error: Could not load tileset")
		quit()
		return
		
	# Populate Source 0
	var source0 = tileset.get_source(0) as TileSetAtlasSource
	if source0:
		var tex = source0.texture
		if tex:
			var cols = 7
			var rows = tex.get_height() / 32
			print("Populating Source 0: %dx%d tiles..." % [cols, rows])
			
			var count = 0
			for y in range(rows):
				for x in range(cols):
					if not source0.has_tile(Vector2i(x, y)):
						source0.create_tile(Vector2i(x, y))
						count += 1
			print("Added %d tiles to Source 0" % count)

	# Populate Source 1
	if tileset.get_source_count() > 1:
		var source1 = tileset.get_source(1) as TileSetAtlasSource
		if source1:
			var tex = source1.texture
			if tex:
				var cols = 7
				var rows = tex.get_height() / 32
				print("Populating Source 1: %dx%d tiles..." % [cols, rows])
				
				var count = 0
				for y in range(rows):
					for x in range(cols):
						if not source1.has_tile(Vector2i(x, y)):
							source1.create_tile(Vector2i(x, y))
							count += 1
				print("Added %d tiles to Source 1" % count)

	# Save
	var err = ResourceSaver.save(tileset, tileset_path)
	if err == OK:
		print("Successfully saved populated tileset!")
	else:
		print("Error saving tileset: ", err)
	
	quit()
