extends Control
## Game Updater/Patcher for Odyssey Revival
## Checks for updates from Cloudflare CDN, downloads patches, and auto-restarts.
## Styled to match the Kenney RPG login screen.

signal update_complete
signal update_failed(error: String)

# Cloudflare CDN URL
const CLOUDFLARE_URL = "https://pub-bfb251fbb7f04473b6eb939aba7ccdfc.r2.dev"

# Constants
const VERSION_FILE = "version.json"
const PATCH_FILE = "game.pck"

# Version is read from ProjectSettings (set in project.godot)
var CURRENT_VERSION: String = ""

var http_request: HTTPRequest
var is_checking: bool = false
var is_downloading: bool = false
var update_channel: String = "production"
var download_start_time: float = 0.0
var last_downloaded_bytes: int = 0
var stall_timer: float = 0.0
const DOWNLOAD_TIMEOUT: float = 30.0

var status_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var update_log: RichTextLabel
var play_button: Button
var version_label: Label
var temp_download_path: String = ""


func _ready():
	# Read version from ProjectSettings
	CURRENT_VERSION = ProjectSettings.get_setting("application/config/version", "0.0.0")

	# Determine channel based on feature tags
	if OS.has_feature("dev_channel"):
		update_channel = "dev"

	create_ui()

	# Auto-check for updates on start
	await get_tree().create_timer(0.5).timeout
	check_for_updates()


func _process(delta: float):
	if is_downloading and http_request:
		var downloaded = http_request.get_downloaded_bytes()
		var total = http_request.get_body_size()

		# Check for stalled download
		if downloaded == last_downloaded_bytes:
			stall_timer += delta
			if stall_timer >= DOWNLOAD_TIMEOUT:
				log_message("Download stalled - no data for %d seconds" % int(DOWNLOAD_TIMEOUT), "red")
				http_request.cancel_request()
				is_downloading = false
				_on_update_check_failed("Download Timeout")
				return
		else:
			stall_timer = 0.0
			last_downloaded_bytes = downloaded

		# Calculate speed
		var elapsed = Time.get_ticks_msec() / 1000.0 - download_start_time
		var speed_mbps = 0.0
		if elapsed > 0:
			speed_mbps = (downloaded / 1048576.0) / elapsed

		if total > 0:
			var percent = (float(downloaded) / float(total)) * 100.0
			progress_bar.value = percent
			var downloaded_mb = downloaded / 1048576.0
			var total_mb = total / 1048576.0
			progress_label.text = "%.1f / %.1f MB (%.0f%%) - %.2f MB/s" % [downloaded_mb, total_mb, percent, speed_mbps]
		elif downloaded > 0:
			var downloaded_mb = downloaded / 1048576.0
			progress_label.text = "%.1f MB downloaded... - %.2f MB/s" % [downloaded_mb, speed_mbps]
		else:
			progress_label.text = "Connecting..."


func create_ui():
	# Background - desert texture like login screen
	var bg_texture = TextureRect.new()
	var desert_tex = load("res://assets/sprites/gui/backgrounds/desert.png")
	if desert_tex:
		bg_texture.texture = desert_tex
		bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_texture.stretch_mode = TextureRect.STRETCH_SCALE
		bg_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg_texture)
	else:
		# Fallback background
		var bg = ColorRect.new()
		bg.color = Color(0.15, 0.12, 0.08, 1.0)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	# Title - Gold RPG style
	var title = Label.new()
	title.text = "ODYSSEYS REVIVAL"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))  # Gold
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0))
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Game Launcher"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Version label
	version_label = Label.new()
	version_label.text = "Version: %s [%s]" % [CURRENT_VERSION, update_channel.to_upper()]
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 14)
	if update_channel == "dev":
		version_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		version_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(version_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# RPG Panel Container (Kenney style)
	var panel_container = PanelContainer.new()
	var panel_texture = load("res://assets/ui/kenney/rpg-expansion/panel_brown.png")
	if panel_texture:
		var stylebox = StyleBoxTexture.new()
		stylebox.texture = panel_texture
		stylebox.texture_margin_left = 16
		stylebox.texture_margin_top = 16
		stylebox.texture_margin_right = 16
		stylebox.texture_margin_bottom = 16
		panel_container.add_theme_stylebox_override("panel", stylebox)
	panel_container.custom_minimum_size = Vector2(550, 0)
	vbox.add_child(panel_container)

	# Inner VBox for panel content
	var panel_vbox = VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 10)
	panel_container.add_child(panel_vbox)

	# Top padding
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 10)
	panel_vbox.add_child(top_spacer)

	# Status label
	status_label = Label.new()
	status_label.text = "Checking for updates..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	panel_vbox.add_child(status_label)

	# Progress bar
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 28)
	progress_bar.value = 0
	progress_bar.show_percentage = false
	panel_vbox.add_child(progress_bar)

	# Progress text
	progress_label = Label.new()
	progress_label.text = ""
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	panel_vbox.add_child(progress_label)

	# Update log label
	var log_title = Label.new()
	log_title.text = "Update Log:"
	log_title.add_theme_font_size_override("font_size", 12)
	log_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	panel_vbox.add_child(log_title)

	# Log panel (inner panel)
	var log_panel = PanelContainer.new()
	var log_stylebox = StyleBoxFlat.new()
	log_stylebox.bg_color = Color(0.1, 0.08, 0.05, 0.8)
	log_stylebox.border_color = Color(0.4, 0.3, 0.2)
	log_stylebox.set_border_width_all(2)
	log_stylebox.set_corner_radius_all(4)
	log_stylebox.set_content_margin_all(8)
	log_panel.add_theme_stylebox_override("panel", log_stylebox)
	log_panel.custom_minimum_size = Vector2(0, 120)
	panel_vbox.add_child(log_panel)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_panel.add_child(scroll)

	update_log = RichTextLabel.new()
	update_log.bbcode_enabled = true
	update_log.fit_content = true
	update_log.scroll_following = true
	update_log.add_theme_font_size_override("normal_font_size", 11)
	update_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(update_log)

	# Bottom padding
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 5)
	panel_vbox.add_child(bottom_spacer)

	# Play button - RPG styled
	var btn_container = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_vbox.add_child(btn_container)

	play_button = Button.new()
	play_button.text = "PLAY GAME"
	play_button.custom_minimum_size = Vector2(200, 50)
	play_button.disabled = true
	play_button.pressed.connect(_on_play_pressed)
	_style_rpg_button(play_button)
	btn_container.add_child(play_button)

	# Final padding
	var final_spacer = Control.new()
	final_spacer.custom_minimum_size = Vector2(0, 10)
	panel_vbox.add_child(final_spacer)

	# HTTP Request
	http_request = HTTPRequest.new()
	http_request.use_threads = true
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)


func _style_rpg_button(btn: Button):
	"""Apply Kenney RPG button styling"""
	var normal_tex = load("res://assets/ui/kenney/rpg-expansion/buttonLong_brown.png")
	var pressed_tex = load("res://assets/ui/kenney/rpg-expansion/buttonLong_brown_pressed.png")

	if normal_tex:
		var normal_style = StyleBoxTexture.new()
		normal_style.texture = normal_tex
		normal_style.texture_margin_left = 8
		normal_style.texture_margin_right = 8
		normal_style.texture_margin_top = 8
		normal_style.texture_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", normal_style)
		btn.add_theme_stylebox_override("focus", normal_style)

	if pressed_tex:
		var pressed_style = StyleBoxTexture.new()
		pressed_style.texture = pressed_tex
		pressed_style.texture_margin_left = 8
		pressed_style.texture_margin_right = 8
		pressed_style.texture_margin_top = 8
		pressed_style.texture_margin_bottom = 8
		btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.75, 0.6))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.45, 0.4))


func log_message(message: String, color: String = "white"):
	var timestamp = Time.get_time_string_from_system()
	update_log.append_text("[color=%s][%s] %s[/color]\n" % [color, timestamp, message])


func check_for_updates():
	log_message("Checking channel: %s..." % update_channel, "yellow")
	status_label.text = "Contacting update server..."
	is_checking = true

	var url = "%s/channels/%s/%s" % [CLOUDFLARE_URL, update_channel, VERSION_FILE]
	url += "?t=" + str(Time.get_unix_time_from_system())

	var error = http_request.request(url)
	if error != OK:
		log_message("Failed to request update check: %s" % error, "red")
		_on_update_check_failed("Internal Error")


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if is_checking:
		_handle_version_check(result, response_code, body)
	elif is_downloading:
		_handle_patch_download(result, response_code, body)


func _handle_version_check(result: int, response_code: int, body: PackedByteArray):
	is_checking = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		log_message("Server unreachable (Code: %d). Playing offline." % response_code, "gray")
		_enable_play()
		return

	var json_text = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_error = json.parse(json_text)

	if parse_error != OK:
		log_message("Invalid server response.", "red")
		_enable_play()
		return

	var data = json.get_data()
	var server_version = data.get("version", CURRENT_VERSION)
	var force_update = data.get("force_update", false)
	var patch_url = data.get("patch_url", "")

	version_label.text = "Client: %s | Server: %s" % [CURRENT_VERSION, server_version]

	if _is_newer_version(server_version, CURRENT_VERSION):
		log_message("Update available: %s" % server_version, "green")

		if patch_url.is_empty():
			patch_url = "%s/channels/%s/%s" % [CLOUDFLARE_URL, update_channel, PATCH_FILE]

		download_patch(patch_url)
	else:
		log_message("Client is up to date!", "green")
		status_label.text = "Ready to play!"
		progress_label.text = ""
		_enable_play()


func _is_newer_version(new_ver: String, current_ver: String) -> bool:
	var v1 = new_ver.split(".")
	var v2 = current_ver.split(".")
	for i in range(min(v1.size(), v2.size())):
		if int(v1[i]) > int(v2[i]): return true
		if int(v1[i]) < int(v2[i]): return false
	return v1.size() > v2.size()


func download_patch(url: String):
	log_message("Downloading update...", "yellow")
	status_label.text = "Downloading update..."
	is_downloading = true
	progress_bar.value = 0
	progress_label.text = "Starting download..."

	download_start_time = Time.get_ticks_msec() / 1000.0
	last_downloaded_bytes = 0
	stall_timer = 0.0

	temp_download_path = OS.get_user_data_dir() + "/update_temp.pck"
	http_request.download_file = temp_download_path
	log_message("Target: %s" % temp_download_path, "gray")

	url += "?t=" + str(Time.get_unix_time_from_system())
	var error = http_request.request(url)
	if error != OK:
		log_message("Download request failed: %s" % error, "red")
		_on_update_check_failed("Download Error")


func _handle_patch_download(result: int, response_code: int, body: PackedByteArray):
	is_downloading = false
	http_request.download_file = ""

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		log_message("Download failed (Result: %d, Code: %d)" % [result, response_code], "red")
		if FileAccess.file_exists(temp_download_path):
			DirAccess.remove_absolute(temp_download_path)
		_on_update_check_failed("Download Failed")
		return

	if not FileAccess.file_exists(temp_download_path):
		log_message("Downloaded file not found!", "red")
		_on_update_check_failed("File Not Found")
		return

	var file_size = FileAccess.open(temp_download_path, FileAccess.READ).get_length()
	var size_mb = file_size / 1048576.0
	log_message("Downloaded %.1f MB. Installing..." % size_mb, "green")
	status_label.text = "Installing update..."
	progress_bar.value = 100
	progress_label.text = "Installing..."

	install_patch_from_file(temp_download_path)


func install_patch_from_file(source_path: String):
	var exe_path = OS.get_executable_path()
	var pck_path = exe_path.get_basename() + ".pck"

	log_message("Installing to: %s" % pck_path, "gray")

	var err = DirAccess.copy_absolute(source_path, pck_path)
	if err == OK:
		log_message("Update installed!", "green")
		progress_bar.value = 100
		progress_label.text = "Complete!"
		status_label.text = "Restarting..."

		DirAccess.remove_absolute(source_path)

		await get_tree().create_timer(1.0).timeout
		OS.set_restart_on_exit(true, [])
		get_tree().quit()
	else:
		log_message("Install failed (Error: %d). Check permissions." % err, "red")
		log_message("Target: %s" % pck_path, "red")
		_on_update_check_failed("Write Access Denied")


func _enable_play():
	play_button.disabled = false
	play_button.text = "PLAY"
	play_button.grab_focus()


func _on_update_check_failed(error: String):
	status_label.text = "Update Failed - " + error
	progress_label.text = ""
	play_button.disabled = false
	play_button.text = "PLAY ANYWAY"


func _on_play_pressed():
	log_message("Starting game...", "green")
	get_tree().change_scene_to_file("res://source/client/gateway/gateway.tscn")
