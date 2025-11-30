class_name BattleSpriteChoreography
extends RefCounted

## Sprite choreography stub - all methods do nothing
## This is a placeholder for the missing choreography system

var sprite_offset: Vector2 = Vector2.ZERO
var duration: float = 0.5
var rotation_degrees: float = 0.0
var scale_factor: float = 1.0
var easing: Tween.EaseType = Tween.EASE_IN_OUT

func _init() -> void:
	pass

func apply_to_sprite(sprite_node: TextureRect) -> void:
	# Do absolutely nothing
	pass
