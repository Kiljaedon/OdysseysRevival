extends Node

# Scene paths
const SCENE_LOGIN = "res://source/client/ui/login_screen.tscn"
const SCENE_CHARACTER_CREATION = "res://source/client/ui/character_creation_screen.tscn" # Assuming this exists or will exist
const SCENE_GATEWAY = "res://source/client/gateway/gateway.tscn"
const SCENE_MAP_LINKER = "res://tools/map_linker/map_linker.tscn"
const SCENE_SPRITE_MAKER = "res://tools/sprite_maker/odyssey_sprite_maker.tscn"
const SCENE_SETTINGS = "res://source/client/ui/settings_screen.tscn"
const SCENE_TEST_ODYSSEY = "res://odyssey_test.tscn"

func goto_scene(path: String):
	"""Generic scene change"""
	print("[SceneNavigation] Changing scene to: ", path)
	get_tree().change_scene_to_file(path)

func goto_login():
	goto_scene(SCENE_LOGIN)

func goto_gateway():
	goto_scene(SCENE_GATEWAY)

func goto_map_linker():
	goto_scene(SCENE_MAP_LINKER)

func goto_sprite_maker():
	goto_scene(SCENE_SPRITE_MAKER)
	
func goto_settings():
	goto_scene(SCENE_SETTINGS)

func goto_test_odyssey():
	goto_scene(SCENE_TEST_ODYSSEY)
