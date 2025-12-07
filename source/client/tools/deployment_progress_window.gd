extends Window
class_name DeploymentProgressWindow
## Shows real-time deployment progress with checklist and logs

signal deployment_finished(success: bool)

# UI Elements
var title_label: Label
var steps_container: VBoxContainer
var log_output: RichTextLabel
var close_button: Button
var progress_bar: ProgressBar

# Step tracking
var steps: Array[Dictionary] = []  # {name, label, status}
var current_step_index: int = -1
var total_steps: int = 0

func _ready():
	_setup_window()
	_create_ui()

func _setup_window():
	title = "Deployment Progress"
	size = Vector2(600, 500)
	position = Vector2(200, 100)
	unresizable = false
	close_requested.connect(_on_close_requested)

func _create_ui():
	var main_container = VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 10)
	main_container.offset_left = 20
	main_container.offset_right = -20
	main_container.offset_top = 20
	main_container.offset_bottom = -20
	add_child(main_container)

	# Title
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)

	# Progress bar
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 25)
	progress_bar.value = 0
	main_container.add_child(progress_bar)

	# Steps checklist panel
	var steps_panel = PanelContainer.new()
	steps_panel.custom_minimum_size = Vector2(0, 150)
	main_container.add_child(steps_panel)

	var steps_scroll = ScrollContainer.new()
	steps_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	steps_panel.add_child(steps_scroll)

	steps_container = VBoxContainer.new()
	steps_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	steps_scroll.add_child(steps_container)

	# Log output panel
	var log_label = Label.new()
	log_label.text = "Log Output:"
	main_container.add_child(log_label)

	var log_panel = PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(log_panel)

	log_output = RichTextLabel.new()
	log_output.set_anchors_preset(Control.PRESET_FULL_RECT)
	log_output.bbcode_enabled = true
	log_output.scroll_following = true
	log_output.selection_enabled = true
	log_panel.add_child(log_output)

	# Close button
	close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(100, 40)
	close_button.disabled = true
	close_button.pressed.connect(_on_close_pressed)
	main_container.add_child(close_button)

	# Center close button
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.remove_child(close_button)
	button_container.add_child(close_button)
	main_container.add_child(button_container)


func initialize(deployment_title: String, step_names: Array):
	"""Initialize the window with deployment type and steps"""
	title_label.text = deployment_title
	title = deployment_title
	total_steps = step_names.size()
	steps.clear()

	# Clear existing step labels
	for child in steps_container.get_children():
		child.queue_free()

	# Create step labels
	for step_name in step_names:
		var step_row = HBoxContainer.new()
		step_row.add_theme_constant_override("separation", 10)

		var status_icon = Label.new()
		status_icon.text = "[ ]"
		status_icon.custom_minimum_size = Vector2(40, 0)
		status_icon.add_theme_font_size_override("font_size", 16)
		step_row.add_child(status_icon)

		var step_label = Label.new()
		step_label.text = step_name
		step_label.add_theme_font_size_override("font_size", 16)
		step_row.add_child(step_label)

		steps_container.add_child(step_row)
		steps.append({
			"name": step_name,
			"row": step_row,
			"icon": status_icon,
			"status": "pending"
		})

	progress_bar.value = 0
	progress_bar.max_value = total_steps
	log_output.clear()
	close_button.disabled = true
	current_step_index = -1


func start_step(step_index: int):
	"""Mark a step as in-progress"""
	if step_index < 0 or step_index >= steps.size():
		return

	current_step_index = step_index
	var step = steps[step_index]
	step.status = "in_progress"
	step.icon.text = "[>]"
	step.icon.add_theme_color_override("font_color", Color.YELLOW)

	log_line("[color=yellow]Starting: %s...[/color]" % step.name)


func complete_step(step_index: int, success: bool = true):
	"""Mark a step as complete or failed"""
	if step_index < 0 or step_index >= steps.size():
		return

	var step = steps[step_index]

	if success:
		step.status = "complete"
		step.icon.text = "[X]"
		step.icon.add_theme_color_override("font_color", Color.GREEN)
		log_line("[color=green]Complete: %s[/color]" % step.name)
	else:
		step.status = "failed"
		step.icon.text = "[!]"
		step.icon.add_theme_color_override("font_color", Color.RED)
		log_line("[color=red]FAILED: %s[/color]" % step.name)

	progress_bar.value = step_index + 1


func log_line(text: String):
	"""Add a line to the log output"""
	var timestamp = Time.get_time_string_from_system()
	log_output.append_text("[%s] %s\n" % [timestamp, text])


func log_data(label: String, data: String):
	"""Add data output to the log"""
	log_output.append_text("[color=cyan]%s:[/color] %s\n" % [label, data])


func finish_deployment(success: bool, summary: String = ""):
	"""Mark deployment as finished"""
	close_button.disabled = false

	if success:
		log_line("\n[color=green]========================================[/color]")
		log_line("[color=green]DEPLOYMENT SUCCESSFUL![/color]")
		if summary:
			log_line("[color=green]%s[/color]" % summary)
		log_line("[color=green]========================================[/color]")
	else:
		log_line("\n[color=red]========================================[/color]")
		log_line("[color=red]DEPLOYMENT FAILED![/color]")
		if summary:
			log_line("[color=red]%s[/color]" % summary)
		log_line("[color=red]========================================[/color]")

	deployment_finished.emit(success)


func _on_close_requested():
	if not close_button.disabled:
		hide()
		queue_free()


func _on_close_pressed():
	hide()
	queue_free()
