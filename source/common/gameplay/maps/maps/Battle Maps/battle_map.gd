@icon("res://assets/node_icons/color/icon_map_colored.png")
class_name BattleMap
extends Node2D
## Base class for battle arena maps
## These are separate scenes used as backgrounds during realtime combat
##
## ARENA SIZE: 892 x 660 pixels
## - Width: 892px (battle window 900 - 8 padding)
## - Height: 660px (battle window 700 - 40 title bar)
##
## Create your battle maps at this size using TileMapLayers

## Battle arena size - MUST match the battle window viewport
const ARENA_WIDTH: int = 892
const ARENA_HEIGHT: int = 660

## Unique identifier for this battle map (used for linking from overworld maps)
@export var battle_map_id: String = ""

## Display name shown during battle
@export var display_name: String = "Battle Arena"

func _ready() -> void:
	pass

func get_arena_size() -> Vector2:
	"""Returns the arena size in pixels"""
	return Vector2(ARENA_WIDTH, ARENA_HEIGHT)
