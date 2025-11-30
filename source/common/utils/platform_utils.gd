extends Node

# Platform detection utilities stub
# Note: Do NOT use class_name here - it conflicts with the autoload singleton

static func is_server() -> bool:
	return OS.has_feature("dedicated_server") or DisplayServer.get_name() == "headless"

static func is_client() -> bool:
	return not is_server()
