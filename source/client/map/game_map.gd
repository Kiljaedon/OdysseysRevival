@tool
class_name GameMap extends TileMap

## The active map data resource for this tilemap.
var map_data: GSMMOMapData

func _ready():
    if not map_data:
        create_default_map()
    draw_map()

func create_default_map():
    map_data = GSMMOMapData.new()
    map_data.map_name = "New In-Game Map"
    for tile in map_data.tiles:
        tile.ground_layer = 1

func draw_map():
    if not map_data or not tile_set:
        return
    clear()
    var source_id = 0
    for y in range(12):
        for x in range(12):
            var i = y * 12 + x
            if i >= map_data.tiles.size(): continue
            var tile_data: GSMMOTileData = map_data.tiles[i]
            var cell_coords = Vector2i(x, y)
            _set_layer_tile(0, cell_coords, source_id, tile_data.ground_layer)
            _set_layer_tile(0, cell_coords, source_id, tile_data.ground_layer_2)
            _set_layer_tile(1, cell_coords, source_id, tile_data.background_layer)
            _set_layer_tile(1, cell_coords, source_id, tile_data.background_layer_2)
            _set_layer_tile(2, cell_coords, source_id, tile_data.foreground_layer)
            _set_layer_tile(2, cell_coords, source_id, tile_data.foreground_layer_2)

func _set_layer_tile(layer: int, coords: Vector2i, source_id: int, tile_id: int):
    if tile_id > 0:
        set_cell(layer, coords, source_id, get_atlas_coords_from_id(tile_id))
    else:
        erase_cell(layer, coords)

func get_atlas_coords_from_id(tile_id: int) -> Vector2i:
    var source: TileSetAtlasSource = tile_set.get_source(0)
    var texture = source.texture
    if not texture:
        return Vector2i(-1, -1)
    var texture_region_size = source.texture_region_size
    var columns = int(texture.get_width() / texture_region_size.x)
    var tile_index = tile_id - 1
    var col = tile_index % columns
    var row = tile_index / columns
    return Vector2i(col, row)
