extends Control
## Game Updater/Patcher for Odyssey Revival
## Checks for updates, downloads patches, and updates the game files

signal update_complete
signal update_failed(error: String)

const UPDATE_SERVER_URL = "http://127.0.0.1:8080"  # Your update server
const VERSION_FILE = "version.json"
const CURRENT_VERSION = "0.1.0"  # Update this with each build

var http_request: HTTPRequest
var is_checking: bool = false
var is_downloading: bool = false

var status_label: Label
var progress_bar: ProgressBar
var update_log: RichTextLabel
var play_button: Button
var version_label: Label


func _ready():
	create_ui()
	check_for_updates()


func create_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(600, 400)
	vbox.add_theme_constant_override("separation", 15)
	center.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "ODYSSEY REVIVAL - UPDATER"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Version
	version_label = Label.new()
	version_label.text = "Version: %s" % CURRENT_VERSION
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(version_label)
	
	# Status
	status_label = Label.new()
	status_label.text = "Checking for updates..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(status_label)
	
	# Progress bar
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 30)
	progress_bar.value = 0
	vbox.add_child(progress_bar)
	
	# Update log
	var log_label = Label.new()
	log_label.text = "Update Log:"
	vbox.add_child(log_label)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(scroll)
	
	update_log = RichTextLabel.new()
	update_log.bbcode_enabled = true
	update_log.fit_content = true
	update_log.scroll_following = true
	scroll.add_child(update_log)
	
	# Play button
	play_button = Button.new()
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(0, 50)
	play_button.disabled = true
	play_button.pressed.connect(_on_play_pressed)
	vbox.add_child(play_button)

	# Skip updater button (for demo/testing without update server)
	var skip_button = Button.new()
	skip_button.text = "Skip Updater (Demo Mode)"
	skip_button.custom_minimum_size = Vector2(0, 40)
	skip_button.pressed.connect(_on_skip_pressed)
	vbox.add_child(skip_button)

	# HTTP Request
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)


func log_message(message: String, color: String = "white"):
	"""Add message to update log"""
	var timestamp = Time.get_time_string_from_system()
	update_log.append_text("[color=%s][%s] %s[/color]\n" % [color, timestamp, message])


func check_for_updates():
	"""Check if updates are available"""
	log_message("Checking for updates...", "yellow")
	status_label.text = "Checking for updates..."
	is_checking = true
	
	var url = UPDATE_SERVER_URL + "/updates/" + VERSION_FILE
	var error = http_request.request(url)
	
	if error != OK:
		log_message("Failed to check for updates: %s" % error, "red")
		_on_update_check_failed("Network error")


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	"""Handle HTTP response"""
	if is_checking:
		_handle_version_check(result, response_code, body)
	elif is_downloading:
		_handle_patch_download(result, response_code, body)


func _handle_version_check(result: int, response_code: int, body: PackedByteArray):
	"""Process version check response"""
	is_checking = false
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		log_message("No updates found or server unreachable", "gray")
		status_label.text = "No updates available"
		play_button.disabled = false
		return
	
	var json_text = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_error = json.parse(json_text)
	
	if parse_error != OK:
		log_message("Failed to parse version info", "red")
		_on_update_check_failed("Invalid version file")
		return
	
	var version_data = json.get_data()
	var latest_version = version_data.get("version", CURRENT_VERSION)
	var patch_url = version_data.get("patch_url", "")
	var changelog = version_data.get("changelog", [])
	
	version_label.text = "Current: %s | Latest: %s" % [CURRENT_VERSION, latest_version]
	
	if _is_newer_version(latest_version, CURRENT_VERSION):
		log_message("Update available: %s -> %s" % [CURRENT_VERSION, latest_version], "green")
		
		# Show changelog
		for change in changelog:
			log_message("  • %s" % change, "cyan")
		
		# Start download
		if patch_url:
			download_patch(patch_url)
		else:
			log_message("No patch URL provided", "red")
			_on_update_check_failed("Missing patch URL")
	else:
		log_message("Game is up to date!", "green")
		status_label.text = "Game is up to date!"
		play_button.disabled = false


func _is_newer_version(new_ver: String, current_ver: String) -> bool:
	"""Compare version strings (major.minor.patch)"""
	var new_parts = new_ver.split(".")
	var cur_parts = current_ver.split(".")
	
	for i in range(min(new_parts.size(), cur_parts.size())):
		var new_num = int(new_parts[i])
		var cur_num = int(cur_parts[i])
		
		if new_num > cur_num:
			return true
		elif new_num < cur_num:
			return false
	
	return new_parts.size() > cur_parts.size()


func download_patch(url: String):
	"""Download patch file"""
	log_message("Downloading update...", "yellow")
	status_label.text = "Downloading update..."
	is_downloading = true
	progress_bar.value = 0
	
	var error = http_request.request(url)
	
	if error != OK:
		log_message("Failed to start download: %s" % error, "red")
		_on_update_check_failed("Download failed")


func _handle_patch_download(result: int, response_code: int, body: PackedByteArray):
	"""Process patch download"""
	is_downloading = false
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		log_message("Failed to download patch", "red")
		_on_update_check_failed("Download failed")
		return
	
	log_message("Patch downloaded successfully (%d bytes)" % body.size(), "green")
	status_label.text = "Installing update..."
	progress_bar.value = 50
	
	# Install patch
	install_patch(body)


func install_patch(patch_data: PackedByteArray):
	"""Install the downloaded patch"""
	log_message("Installing patch...", "yellow")
	
	# For .pck files, save to game directory
	var game_dir = OS.get_executable_path().get_base_dir()
	var patch_path = game_dir.path_join("patch.pck")
	
	var file = FileAccess.open(patch_path, FileAccess.WRITE)
	if file:
		file.store_buffer(patch_data)
		file.close()
		log_message("Patch installed to: %s" % patch_path, "green")
		
		# Load the new .pck
		var loaded = ProjectSettings.load_resource_pack(patch_path, true)
		if loaded:
			log_message("Patch loaded successfully!", "green")
			status_label.text = "Update complete!"
			progress_bar.value = 100
			play_button.disabled = false
			update_complete.emit()
		else:
			log_message("Failed to load patch file", "red")
			_on_update_check_failed("Patch load failed")
	else:
		log_message("Failed to save patch file", "red")
		_on_update_check_failed("File write error")


func _on_update_check_failed(error: String):
	"""Handle update failure"""
	status_label.text = "Update failed - Playing current version"
	log_message("Update failed: %s" % error, "orange")
	play_button.disabled = false
	update_failed.emit(error)


func _on_play_pressed():
	"""Launch the game"""
	log_message("Starting game...", "green")
	get_tree().change_scene_to_file("res://source/client/gateway/gateway.tscn")


func _on_skip_pressed():
	"""Skip updater and go to main menu (for demo/testing)"""
	log_message("Skipping updater - going to main menu...", "cyan")
	get_tree().change_scene_to_file("res://source/client/gateway/gateway.tscn")
