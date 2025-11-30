class_name Music
extends RefCounted

# Music system - stub for client-first development
static var instance: Music

static func get_instance() -> Music:
	if not instance:
		instance = Music.new()
	return instance

static func play(track: String = ""):
	pass

static func stop_music():
	pass

static func get_playing_track() -> String:
	return ""