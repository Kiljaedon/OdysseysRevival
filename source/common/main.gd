extends Node
## Main Scene - This is the entry point of the application (set at application/run/main_scene).
## Its sole responsibility is to determine and initialize the application role
## (world server, gateway server, master server, or client) based on feature flags.


func _ready() -> void:
	var features: Dictionary[String, Callable] = {
		"client": start_as_client,
		"gateway-server": start_as_gateway_server,
		"master-server": start_as_master_server,
		"world-server": start_as_world_server,
	}
	
	var command_line_arg: String = CmdlineUtils.get_parsed_args().get("mode", "")
	
	if features.has(command_line_arg):
		features[command_line_arg].call()
		return
	
	for feature: String in features:
		if OS.has_feature(feature):
			features[feature].call()
			return
	
	print_rich("[color=yellow]No feature tag found. Loading client as default.[/color]")
	get_tree().change_scene_to_file.call_deferred("res://source/client/client_main.tscn")


func start_as_client() -> void:
	# If exported (standalone), show updater first
	if OS.has_feature("standalone") or OS.has_feature("pc"):
		get_tree().change_scene_to_file.call_deferred("res://source/client/updater/game_updater.tscn")
	else:
		# Running in editor - skip updater
		get_tree().change_scene_to_file.call_deferred("res://source/client/client_main.tscn")


func start_as_gateway_server() -> void:
	get_tree().change_scene_to_file.call_deferred("res://source/server/gateway/gateway_main.tscn")


func start_as_master_server() -> void:
	get_tree().change_scene_to_file.call_deferred("res://source/server/master/master_main.tscn")


func start_as_world_server() -> void:
	get_tree().change_scene_to_file.call_deferred("res://source/server/server_world.tscn")
