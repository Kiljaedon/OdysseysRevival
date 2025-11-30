# addons/gs_mmo_tools/resources/sprite_data.gd
@tool
class_name SpriteData extends Resource

## The texture containing the sprite sheet.
@export var texture: Texture2D

## The size of a single frame in the sprite sheet.
@export var frame_size: Vector2i = Vector2i(32, 32)

## A dictionary of animations. The key is the animation name (e.g., "walk_down")
## and the value is a dictionary with "frames" (Array[int]) and "direction" (String).
@export var animations: Dictionary = {}

## The game class that this sprite is bound to.
@export var game_class_name: StringName = &""

## If true, this will be used to auto-generate a character scene.
@export var auto_generate_class: bool = false
