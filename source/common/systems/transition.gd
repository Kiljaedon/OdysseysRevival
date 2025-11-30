class_name Transition
extends RefCounted

# Transition system - stub for client-first development
signal finished
var is_clear: bool = false

static var instance: Transition

static func get_instance() -> Transition:
	if not instance:
		instance = Transition.new()
	return instance

static func cover():
	pass

static func clear():
	pass