extends Control
## Game Updater/Patcher for Odysseys Revival
## Professional Kenney RPG-styled launcher with step-by-step update visualization

signal update_complete
signal update_failed(error: String)

# Cloudflare CDN URL
const CLOUDFLARE_URL = "https://pub-bfb251fbb7f04473b6eb939aba7ccdfc.r2.dev"
const VERSION_FILE = "version.json"
const PATCH_FILE = "game.pck"

# Version from GameVersion class (in PCK)
var CURRENT_VERSION: String = ""

# HTTP
var http_request: HTTPRequest
var is_checking: bool = false
var is_downloading: bool = false
var update_channel: String = "production"
var download_start_time: float = 0.0
var last_downloaded_bytes: int = 0
var stall_timer: float = 0.0
const DOWNLOAD_TIMEOUT: float = 30.0
var temp_download_path: String = ""

# UI Elements
var title_label: Label
var version_label: Label
var status_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var step_container: VBoxContainer
var log_output: RichTextLabel
var play_button: Button

# Step tracking
var steps: Array[Dictionary] = []
var current_step: int = -1

# Kenney assets
var kenney_font: Font
var icon_pending: Texture2D
var icon_active: Texture2D
var icon_complete: Texture2D
var icon_failed: Texture2D


func _ready():
	CURRENT_VERSION = GameVersion.GAME_VERSION

	# Determine channel
	if OS.has_feature("dev_channel"):
		update_channel = "dev"

	_load_assets()
	_create_ui()

	# Auto-check after brief delay
	await get_tree().create_timer(0.3).timeout
	_start_update_check()


func _process(delta: float):
	if is_downloading and http_request:
		_update_download_progress(delta)


func _load_assets():
	"""Load Kenney assets for UI"""
	kenney_font = load("res://assets/ui/kenney/Font/Kenney Future.ttf")
	icon_pending = load("res://assets/ui/kenney/rpg-expansion/iconCircle_grey.png")
	icon_active = load("res://assets/ui/kenney/rpg-expansion/iconCircle_blue.png")
	icon_complete = load("res://assets/ui/kenney/rpg-expansion/iconCheck_bronze.png")
	icon_failed = load("res://assets/ui/kenney/rpg-expansion/iconCross_brown.png")


func _create_ui():
	"""Build the professional RPG-styled UI"""

	# === BACKGROUND ===
	# Desert sand fill (prevents black letterboxing)
	var bg_fill = ColorRect.new()
	bg_fill.color = Color(0.82, 0.65, 0.42, 1.0)
	bg_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_fill.z_index = -2
	add_child(bg_fill)

	# Desert texture background
	var bg_texture = TextureRect.new()
	var desert_tex = load("res://assets/sprites/gui/backgrounds/desert.png")
	if desert_tex:
		bg_texture.texture = desert_tex
		bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_texture.stretch_mode = TextureRect.STRETCH_SCALE
		bg_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_texture.z_index = -1
		add_child(bg_texture)

	# === MAIN CONTAINER ===
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	center.add_child(main_vbox)

	# === TITLE SECTION ===
	title_label = Label.new()
	title_label.text = "ODYSSEYS REVIVAL"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if kenney_font:
		title_label.add_theme_font_override("font", kenney_font)
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))  # Gold
	title_label.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.0))
	title_label.add_theme_constant_override("outline_size", 4)
	main_vbox.add_child(title_label)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Game Launcher"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	main_vbox.add_child(subtitle)

	# Version info
	version_label = Label.new()
	var channel_text = " [DEV]" if update_channel == "dev" else ""
	version_label.text = "Version %s%s" % [CURRENT_VERSION, channel_text]
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 14)
	if update_channel == "dev":
		version_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		version_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	main_vbox.add_child(version_label)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 5)
	main_vbox.add_child(spacer1)

	# === MAIN PANEL (Kenney Brown) ===
	var main_panel = PanelContainer.new()
	var panel_tex = load("res://assets/ui/kenney/rpg-expansion/panel_brown.png")
	if panel_tex:
		var style = StyleBoxTexture.new()
		style.texture = panel_tex
		style.texture_margin_left = 16
		style.texture_margin_top = 16
		style.texture_margin_right = 16
		style.texture_margin_bottom = 16
		style.content_margin_left = 25
		style.content_margin_top = 25
		style.content_margin_right = 25
		style.content_margin_bottom = 25
		main_panel.add_theme_stylebox_override("panel", style)
	main_panel.custom_minimum_size = Vector2(550, 0)
	main_vbox.add_child(main_panel)

	var panel_content = VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 12)
	main_panel.add_child(panel_content)

	# === STATUS LABEL ===
	status_label = Label.new()
	status_label.text = "Preparing..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	panel_content.add_child(status_label)

	# === STEP CHECKLIST (Inset Panel) ===
	var steps_panel = PanelContainer.new()
	var inset_tex = load("res://assets/ui/kenney/rpg-expansion/panelInset_brown.png")
	if inset_tex:
		var inset_style = StyleBoxTexture.new()
		inset_style.texture = inset_tex
		inset_style.texture_margin_left = 8
		inset_style.texture_margin_top = 8
		inset_style.texture_margin_right = 8
		inset_style.texture_margin_bottom = 8
		inset_style.content_margin_left = 15
		inset_style.content_margin_top = 12
		inset_style.content_margin_right = 15
		inset_style.content_margin_bottom = 12
		steps_panel.add_theme_stylebox_override("panel", inset_style)
	steps_panel.custom_minimum_size = Vector2(0, 120)
	panel_content.add_child(steps_panel)

	step_container = VBoxContainer.new()
	step_container.add_theme_constant_override("separation", 8)
	steps_panel.add_child(step_container)

	# === PROGRESS BAR ===
	var progress_container = VBoxContainer.new()
	progress_container.add_theme_constant_override("separation", 4)
	panel_content.add_child(progress_container)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 24)
	progress_bar.value = 0
	progress_bar.show_percentage = false
	# Style progress bar
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.15, 0.1)
	bar_bg.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.4, 0.7, 0.3)  # Green
	bar_fill.set_corner_radius_all(4)
	progress_bar.add_theme_stylebox_override("fill", bar_fill)
	progress_container.add_child(progress_bar)

	progress_label = Label.new()
	progress_label.text = ""
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	progress_container.add_child(progress_label)

	# === LOG OUTPUT ===
	var log_label = Label.new()
	log_label.text = "Update Log"
	log_label.add_theme_font_size_override("font_size", 12)
	log_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	panel_content.add_child(log_label)

	var log_panel = PanelContainer.new()
	var log_style = StyleBoxFlat.new()
	log_style.bg_color = Color(0.08, 0.06, 0.04, 0.9)
	log_style.border_color = Color(0.3, 0.25, 0.18)
	log_style.set_border_width_all(2)
	log_style.set_corner_radius_all(4)
	log_style.set_content_margin_all(10)
	log_panel.add_theme_stylebox_override("panel", log_style)
	log_panel.custom_minimum_size = Vector2(0, 100)
	panel_content.add_child(log_panel)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_panel.add_child(scroll)

	log_output = RichTextLabel.new()
	log_output.bbcode_enabled = true
	log_output.fit_content = true
	log_output.scroll_following = true
	log_output.add_theme_font_size_override("normal_font_size", 11)
	log_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(log_output)

	# === PLAY BUTTON ===
	var btn_container = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_content.add_child(btn_container)

	play_button = Button.new()
	play_button.text = "CHECKING..."
	play_button.custom_minimum_size = Vector2(200, 50)
	play_button.disabled = true
	play_button.pressed.connect(_on_play_pressed)
	_style_button(play_button)
	btn_container.add_child(play_button)

	# === HTTP REQUEST ===
	http_request = HTTPRequest.new()
	http_request.use_threads = true
	http_request.request_completed.connect(_on_request_completed)
	add_child(http_request)


func _style_button(btn: Button):
	"""Apply Kenney RPG button styling"""
	var normal_tex = load("res://assets/ui/kenney/rpg-expansion/buttonLong_brown.png")
	var pressed_tex = load("res://assets/ui/kenney/rpg-expansion/buttonLong_brown_pressed.png")

	if normal_tex:
		var normal_style = StyleBoxTexture.new()
		normal_style.texture = normal_tex
		normal_style.texture_margin_left = 12
		normal_style.texture_margin_right = 12
		normal_style.texture_margin_top = 12
		normal_style.texture_margin_bottom = 12
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", normal_style)
		btn.add_theme_stylebox_override("focus", normal_style)

		# Disabled style (greyed out)
		var disabled_style = normal_style.duplicate()
		btn.add_theme_stylebox_override("disabled", disabled_style)

	if pressed_tex:
		var pressed_style = StyleBoxTexture.new()
		pressed_style.texture = pressed_tex
		pressed_style.texture_margin_left = 12
		pressed_style.texture_margin_right = 12
		pressed_style.texture_margin_top = 12
		pressed_style.texture_margin_bottom = 12
		btn.add_theme_stylebox_override("pressed", pressed_style)

	if kenney_font:
		btn.add_theme_font_override("font", kenney_font)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.75, 0.6))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.45, 0.4))


# ============================================================================
# STEP MANAGEMENT
# ============================================================================

func _init_steps():
	"""Initialize the update step checklist"""
	steps.clear()
	for child in step_container.get_children():
		child.queue_free()

	var step_names = [
		"Connecting to update server...",
		"Checking for updates...",
		"Downloading update...",
		"Installing update...",
		"Ready to play!"
	]

	for step_name in step_names:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var icon = TextureRect.new()
		icon.texture = icon_pending
		icon.custom_minimum_size = Vector2(24, 24)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

		var label = Label.new()
		label.text = step_name
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
		row.add_child(label)

		step_container.add_child(row)
		steps.append({"row": row, "icon": icon, "label": label, "name": step_name})


func _set_step_active(index: int):
	"""Mark a step as active (in progress)"""
	if index < 0 or index >= steps.size():
		return
	current_step = index
	var step = steps[index]
	step.icon.texture = icon_active
	step.label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	step.icon.modulate = Color(1.2, 1.2, 1.5)  # Slight blue glow


func _set_step_complete(index: int):
	"""Mark a step as complete"""
	if index < 0 or index >= steps.size():
		return
	var step = steps[index]
	step.icon.texture = icon_complete
	step.icon.modulate = Color(1.0, 1.0, 1.0)
	step.label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.5))  # Green


func _set_step_failed(index: int):
	"""Mark a step as failed"""
	if index < 0 or index >= steps.size():
		return
	var step = steps[index]
	step.icon.texture = icon_failed
	step.icon.modulate = Color(1.0, 1.0, 1.0)
	step.label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))  # Red


# ============================================================================
# UPDATE LOGIC
# ============================================================================

func _start_update_check():
	"""Begin the update check process"""
	_init_steps()
	_log("Launcher started - Version %s" % CURRENT_VERSION, "gray")
	_log("Update channel: %s" % update_channel.to_upper(), "yellow")

	# Step 0: Connecting
	_set_step_active(0)
	status_label.text = "Connecting to update server..."

	var url = "%s/channels/%s/%s?t=%d" % [CLOUDFLARE_URL, update_channel, VERSION_FILE, Time.get_unix_time_from_system()]
	_log("Checking: %s" % url, "gray")

	is_checking = true
	var error = http_request.request(url)
	if error != OK:
		_log("Connection failed: %s" % error, "red")
		_set_step_failed(0)
		_enable_play_anyway()


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if is_checking:
		_handle_version_check(result, response_code, body)
	elif is_downloading:
		_handle_download_complete(result, response_code)


func _handle_version_check(result: int, response_code: int, body: PackedByteArray):
	is_checking = false
	_set_step_complete(0)

	# Step 1: Checking version
	_set_step_active(1)
	status_label.text = "Checking for updates..."

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_log("Server unreachable (Code: %d)" % response_code, "orange")
		_log("Playing in offline mode", "gray")
		_set_step_complete(1)
		_skip_to_ready()
		return

	var json_text = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(json_text) != OK:
		_log("Invalid server response", "red")
		_set_step_failed(1)
		_enable_play_anyway()
		return

	var data = json.get_data()
	var server_version = data.get("version", CURRENT_VERSION)

	version_label.text = "Local: %s | Server: %s" % [CURRENT_VERSION, server_version]
	_log("Server version: %s" % server_version, "cyan")

	if _is_newer_version(server_version, CURRENT_VERSION):
		_log("Update available!", "green")
		_set_step_complete(1)
		_start_download(server_version)
	else:
		_log("Already up to date!", "green")
		_set_step_complete(1)
		_skip_to_ready()


func _start_download(new_version: String):
	"""Download the game patch"""
	_set_step_active(2)
	status_label.text = "Downloading v%s..." % new_version
	progress_bar.value = 0
	progress_label.text = "Starting download..."

	is_downloading = true
	download_start_time = Time.get_ticks_msec() / 1000.0
	last_downloaded_bytes = 0
	stall_timer = 0.0

	temp_download_path = OS.get_user_data_dir() + "/update_temp.pck"
	http_request.download_file = temp_download_path

	var url = "%s/channels/%s/%s?t=%d" % [CLOUDFLARE_URL, update_channel, PATCH_FILE, Time.get_unix_time_from_system()]
	_log("Downloading from: %s" % url, "gray")

	var error = http_request.request(url)
	if error != OK:
		_log("Download request failed: %s" % error, "red")
		_set_step_failed(2)
		is_downloading = false
		_enable_play_anyway()


func _update_download_progress(delta: float):
	"""Update download progress display"""
	var downloaded = http_request.get_downloaded_bytes()
	var total = http_request.get_body_size()

	# Stall detection
	if downloaded == last_downloaded_bytes:
		stall_timer += delta
		if stall_timer >= DOWNLOAD_TIMEOUT:
			_log("Download stalled - timeout", "red")
			http_request.cancel_request()
			is_downloading = false
			_set_step_failed(2)
			_enable_play_anyway()
			return
	else:
		stall_timer = 0.0
		last_downloaded_bytes = downloaded

	# Calculate speed
	var elapsed = Time.get_ticks_msec() / 1000.0 - download_start_time
	var speed_mbps = (downloaded / 1048576.0) / max(elapsed, 0.1)

	if total > 0:
		var percent = (float(downloaded) / float(total)) * 100.0
		progress_bar.value = percent
		var dl_mb = downloaded / 1048576.0
		var total_mb = total / 1048576.0
		progress_label.text = "%.1f / %.1f MB (%.0f%%) - %.2f MB/s" % [dl_mb, total_mb, percent, speed_mbps]
	elif downloaded > 0:
		progress_label.text = "%.1f MB - %.2f MB/s" % [downloaded / 1048576.0, speed_mbps]


func _handle_download_complete(result: int, response_code: int):
	is_downloading = false
	http_request.download_file = ""

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_log("Download failed (Code: %d)" % response_code, "red")
		if FileAccess.file_exists(temp_download_path):
			DirAccess.remove_absolute(temp_download_path)
		_set_step_failed(2)
		_enable_play_anyway()
		return

	if not FileAccess.file_exists(temp_download_path):
		_log("Downloaded file not found!", "red")
		_set_step_failed(2)
		_enable_play_anyway()
		return

	var file_size = FileAccess.open(temp_download_path, FileAccess.READ).get_length()
	_log("Downloaded %.1f MB" % (file_size / 1048576.0), "green")
	progress_bar.value = 100
	_set_step_complete(2)

	# Step 3: Installing
	_install_update()


func _install_update():
	"""Install the downloaded patch"""
	_set_step_active(3)
	status_label.text = "Installing update..."
	progress_label.text = "Installing..."
	_log("Installing update...", "yellow")

	var exe_path = OS.get_executable_path()
	var pck_path = exe_path.get_basename() + ".pck"

	_log("Target: %s" % pck_path, "gray")

	var err = DirAccess.copy_absolute(temp_download_path, pck_path)
	if err == OK:
		_log("Update installed successfully!", "green")
		_set_step_complete(3)
		DirAccess.remove_absolute(temp_download_path)

		status_label.text = "Restarting..."
		progress_label.text = "Update complete!"

		await get_tree().create_timer(1.5).timeout
		OS.set_restart_on_exit(true, [])
		get_tree().quit()
	else:
		_log("Install failed (Error: %d)" % err, "red")
		_log("Check write permissions", "orange")
		_set_step_failed(3)
		_enable_play_anyway()


func _skip_to_ready():
	"""Skip remaining steps and enable play"""
	# Mark steps 2, 3 as skipped (grayed)
	for i in range(2, 4):
		if i < steps.size():
			steps[i].label.text = steps[i].name.replace("...", " (skipped)")
			steps[i].label.add_theme_color_override("font_color", Color(0.5, 0.48, 0.45))

	_set_step_complete(4)
	status_label.text = "Ready to Play!"
	progress_bar.value = 100
	progress_label.text = ""
	_enable_play()


func _enable_play():
	"""Enable the play button"""
	play_button.disabled = false
	play_button.text = "PLAY"
	play_button.grab_focus()


func _enable_play_anyway():
	"""Enable play button after error"""
	play_button.disabled = false
	play_button.text = "PLAY ANYWAY"
	status_label.text = "Update check failed"


func _on_play_pressed():
	_log("Starting game...", "green")
	get_tree().change_scene_to_file("res://source/client/gateway/gateway.tscn")


# ============================================================================
# UTILITIES
# ============================================================================

func _log(message: String, color: String = "white"):
	"""Add message to log output"""
	var timestamp = Time.get_time_string_from_system()
	log_output.append_text("[color=%s][%s] %s[/color]\n" % [color, timestamp, message])


func _is_newer_version(new_ver: String, current_ver: String) -> bool:
	"""Compare version strings"""
	var v1 = new_ver.split(".")
	var v2 = current_ver.split(".")
	for i in range(min(v1.size(), v2.size())):
		if int(v1[i]) > int(v2[i]):
			return true
		if int(v1[i]) < int(v2[i]):
			return false
	return v1.size() > v2.size()
