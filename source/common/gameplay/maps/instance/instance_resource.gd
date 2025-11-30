class_name InstanceResource
extends Resource


@export var instance_name: StringName
@export_file("*.tscn") var map_path: String
@export var load_at_startup: bool = false

var loading_instances: Array
# NETWORK DEPENDENCY DISABLED FOR CLIENT-FIRST DEVELOPMENT
# Original: var charged_instances: Array[ServerInstance]
var charged_instances: Array # Generic array until ServerInstance is restored


@warning_ignore("unused_parameter")
func can_join_instance(player: GamePlayer, index: int = -1) -> bool:
	return true


# NETWORK DEPENDENCY DISABLED FOR CLIENT-FIRST DEVELOPMENT
# Original: func get_instance(index: int = -1) -> ServerInstance:
func get_instance(index: int = -1): # Generic return type until ServerInstance is restored
	if charged_instances.is_empty() or charged_instances.size() <= index:
		return null
	return charged_instances[index]
