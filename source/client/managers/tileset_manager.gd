class_name TilesetManager
extends Node

## Manages tileset initialization and configuration for the game client.
## Responsible for setting up tile atlas sources and collision system.
##
## Features:
## - Dynamic tileset tile creation for both atlas sources
## - Validation of tileset configuration
## - Support for multi-source tileset systems (tiles_part1, tiles_part2)
##
## Dependencies:
## - TileMapLayer nodes (bottom_layer, middle_layer, top_layer)
##
## Usage:
## var tileset_mgr = TilesetManager.new()
## tileset_mgr.initialize(bottom_layer, middle_layer, top_layer)
## tileset_mgr.setup_tileset_tiles()

var bottom_layer: TileMapLayer
var middle_layer: TileMapLayer
var top_layer: TileMapLayer

func initialize(bottom: TileMapLayer, middle: TileMapLayer, top: TileMapLayer) -> void:
	"""Initialize tileset manager with tile layer references."""
	bottom_layer = bottom
	middle_layer = middle
	top_layer = top
	print("[TilesetManager] Initialized")

func setup_tileset_tiles() -> void:
	"""Setup tileset tiles - main tileset has NO collision."""
	print("[TilesetManager] Checking tileset setup...")

	var tileset = bottom_layer.tile_set
	if not tileset:
		print("[TilesetManager] ERROR: No tileset assigned to map layers")
		return

	print("[TilesetManager] Tileset found: %s" % tileset)
	print("[TilesetManager] Source count: %d" % tileset.get_source_count())

	# Check source 0 (tiles_part1)
	var source0 = tileset.get_source(0) as TileSetAtlasSource
	if source0:
		print("[TilesetManager] Source 0 texture: %s" % source0.texture)
		if source0.texture:
			print("[TilesetManager] Source 0 texture size: %s" % source0.texture.get_size())
		else:
			print("[TilesetManager] ERROR: Source 0 texture is NULL!")
		print("[TilesetManager] Source 0 tiles count before: %d" % source0.get_tiles_count())
		if source0.get_tiles_count() == 0:
			print("[TilesetManager] Setting up tiles_part1 (source 0)...")
			for y in range(512):  # 512 rows
				for x in range(7):  # 7 columns
					source0.create_tile(Vector2i(x, y))
			print("[TilesetManager] Created tiles for source 0: ", source0.get_tiles_count())
		else:
			print("[TilesetManager] Source 0 already has %d tiles" % source0.get_tiles_count())
	else:
		print("[TilesetManager] ERROR: Source 0 not found!")

	# Check source 1 (tiles_part2)
	if tileset.get_source_count() > 1:
		var source1 = tileset.get_source(1) as TileSetAtlasSource
		if source1:
			print("[TilesetManager] Source 1 texture: %s" % source1.texture)
			print("[TilesetManager] Source 1 tiles count before: %d" % source1.get_tiles_count())
			if source1.get_tiles_count() == 0:
				print("[TilesetManager] Setting up tiles_part2 (source 1)...")
				for y in range(485):  # 485 rows
					for x in range(7):  # 7 columns
						source1.create_tile(Vector2i(x, y))
				print("[TilesetManager] Created tiles for source 1: ", source1.get_tiles_count())
			else:
				print("[TilesetManager] Source 1 already has %d tiles" % source1.get_tiles_count())

	# Debug: Check layer visibility
	print("[TilesetManager] BottomLayer visible: %s, modulate: %s" % [bottom_layer.visible, bottom_layer.modulate])
	print("[TilesetManager] MiddleLayer visible: %s, modulate: %s" % [middle_layer.visible, middle_layer.modulate])
	print("[TilesetManager] TopLayer visible: %s, modulate: %s" % [top_layer.visible, top_layer.modulate])

	print("[TilesetManager] Tileset setup complete")
	print("COLLISION SYSTEM:")
	print("  - 3 tile layers: Bottom (terrain), Middle (objects), Top (foreground)")
	print("  - Collision: Object layer with resizable rectangles")
	print("  - In Tiled: Create Object Layer named 'Collision'")
	print("  - Use Rectangle tool (R key) to draw collision boxes")
	print("  - Drag corners to resize collision areas")
	print("  - Objects converted to StaticBody2D collision shapes in Godot")
	print("  - No more fixed tile-grid collision - fully customizable!")
