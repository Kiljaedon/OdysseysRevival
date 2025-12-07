extends Node

var current_username: String = ""
var current_character: Dictionary = {}
var selected_character: Dictionary = {}
var character_source: String = ""
var client: Node = null  # ServerConnection reference
var world_client: Node = null  # WorldClient connection (persists across scene changes)

# Login/Character select data
var select_username: String = ""  # Username for character select screen
var select_characters: Array = []  # Character list from login

# Admin/Developer data
var admin_level: int = 0  # 0 = regular user, 1 = admin, 2 = superadmin

# Battle system data
var pre_battle_position: Vector2 = Vector2.ZERO  # Player position before entering battle
var server_npcs_data: Array = []  # Store NPC data across battle scene changes

func set_player_character(character_data: Dictionary):
	"""Set the selected player character from character selection"""
	selected_character = character_data.duplicate(true)
	character_source = "player"
	print("GameState: Player character set: ", character_data.get("character_name", "Unknown"))

func clear_character():
	"""Clear selected character"""
	selected_character = {}
	character_source = ""
