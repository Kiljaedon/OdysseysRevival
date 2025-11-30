# DELETED SYSTEMS: Equipment system references removed GearItem class
# This component will be rebuilt for custom items created through sprite editor
# See DEVELOPMENT_NOTES.md for custom development approach

class_name EquipmentComponent
extends Node

@export var _asc: AbilitySystemComponent
@export var character: Character

# DELETED SYSTEMS: GearItem references commented out
# var _slots: Dictionary[StringName, GearItem] = {}

func _ready() -> void:
	# Placeholder for custom equipment system
	pass

# DELETED SYSTEMS: All equipment functions commented out - will be rebuilt for custom items
# func equip(slot: StringName, item: GearItem) -> bool:
#	if _slots.has(slot):
#		_unequip_internal(slot)
#	_slots[slot] = item
#	item.on_equip(character)
#	return true

# func unequip(slot: StringName) -> void:
#	if not _slots.has(slot):
#		return
#	_unequip_internal(slot)

# func _unequip_internal(slot: StringName) -> void:
#	var item: GearItem = _slots[slot]
#	item.on_unequip(character)
#	_slots.erase(slot)
