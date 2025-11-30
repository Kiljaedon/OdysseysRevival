class_name WeaponState
extends Node
## Weapon Sheath State Component
## Manages whether a character's weapon is sheathed or unsheathed
## Used to prevent attacks when weapon is sheathed

# Signals
signal state_changed(is_sheathed: bool)
signal weapon_sheathed()
signal weapon_unsheathed()

# Properties
@export var start_sheathed: bool = true  ## Should weapon start sheathed?

var is_sheathed: bool = true:
	set(value):
		if is_sheathed != value:
			is_sheathed = value
			state_changed.emit(is_sheathed)

			if is_sheathed:
				weapon_sheathed.emit()
				print("[WeaponState] Weapon sheathed")
			else:
				weapon_unsheathed.emit()
				print("[WeaponState] Weapon unsheathed - ready for combat")


func _ready() -> void:
	is_sheathed = start_sheathed
	print("[WeaponState] Initialized - Weapon %s" % ("sheathed" if is_sheathed else "unsheathed"))


## Toggle between sheathed and unsheathed states
func toggle() -> void:
	is_sheathed = not is_sheathed


## Sheath the weapon (set to sheathed state)
func sheath() -> void:
	is_sheathed = true


## Unsheath the weapon (set to unsheathed/ready state)
func unsheath() -> void:
	is_sheathed = false


## Returns true if weapon is ready for combat (unsheathed)
func can_attack() -> bool:
	return not is_sheathed


## Returns true if weapon is safely stored (sheathed)
func is_safe() -> bool:
	return is_sheathed


## Get current state as string for debugging
func get_state_string() -> String:
	return "sheathed" if is_sheathed else "unsheathed"
