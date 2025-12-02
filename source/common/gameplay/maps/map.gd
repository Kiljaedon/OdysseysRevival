@icon("res://assets/node_icons/color/icon_map_colored.png")
class_name Map
extends Node2D


@export var replicated_props_container: ReplicatedPropsContainer
@export var map_background_color := Color(0,0,0)

## DEPRECATED: No longer used - world maps now serve as battle arenas directly
## The realtime battle system uses the current world map as the battle background
@export var battle_map_path: String = ""

var warpers: Dictionary[int, Warper]


func _ready() -> void:
	for child: Node in get_children():
		if child is Warper:
			var warper_id: int = child.warper_id
			warpers[warper_id] = child


func get_spawn_position(warper_id: int = 0) -> Vector2:
	if warpers.has(warper_id):
		return warpers[warper_id].global_position
	return Vector2.ZERO


# NETWORK DEPENDENCY DISABLED FOR CLIENT-FIRST DEVELOPMENT
# Original: func get_default_state_synchronizers() -> Array[StateSynchronizer]:
func get_default_state_synchronizers() -> Array: # Generic array until StateSynchronizer is restored
	# Original: return find_children("*", "StateSynchronizer", true) as Array[StateSynchronizer]
	return [] # Empty array for client-first development
