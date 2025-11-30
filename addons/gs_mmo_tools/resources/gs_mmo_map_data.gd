@tool
class_name GSMMOMapData extends Resource

@export var map_name: String = "New Map"
@export var music: AudioStream
@export var exit_up: int = 0
@export var exit_down: int = 0
@export var exit_left: int = 0
@export var exit_right: int = 0
@export var death_location_map: int = 0
@export var death_location_pos: Vector2i = Vector2i.ZERO
@export var default_npc: int = 0
@export var monster_spawns: Array = []
@export_flags("Indoors", "Always Dark", "Arena", "No Monster Attacks", "Double Monsters") var flags: int = 0
@export var tiles: Array[GSMMOTileData] = []

func _init():
    if tiles.is_empty():
        tiles.resize(12 * 12)
        for i in range(12 * 12):
            tiles[i] = GSMMOTileData.new()
