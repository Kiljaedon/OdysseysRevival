extends EditorExportPlugin


func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	if features.has("client"):
		return

	# Server export - disable client-only autoloads
	var override_content: String = """[autoload]
WindowFix=null
UIScaler=null
MainMenuHandler=null"""

	add_file(
		"override.cfg",
		override_content.to_utf8_buffer(),
		true
	)
	print("Server export detected. Disabling client-only autoloads (WindowFix, UIScaler, MainMenuHandler)...")


func _export_end() -> void:
	pass


func _get_name() -> String:
	return "No Client Autoload"
