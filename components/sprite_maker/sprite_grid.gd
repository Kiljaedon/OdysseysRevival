class_name SpriteMakerGrid extends RefCounted
## Handles sprite grid display, selection, and pagination for Sprite Maker

signal sprite_row_selected(row: int, sprite_data: Array)
signal status_changed(message: String)

# Constants
const CHARACTER_ROWS = 644
const SPRITE_SIZE = 32
const COLS_PER_ROW = 12
const ROWS_PER_ATLAS = 512
const PREVIEW_COL = 3
const CROP_EDGE = 0

# State
var sprite_regions: Array[Dictionary] = []
var atlas_textures: Array[Texture2D] = []
var sprite_cache: Dictionary = {}
var loaded_buttons: Dictionary = {}
var selection_start: int = -1
var selected_sprites: Array = []

# Pagination
var current_page: int = 0
var rows_per_page: int = 50
var total_pages: int = 0

# UI References (set via initialize)
var grid_container: GridContainer
var scroll_container: ScrollContainer

var animation_names: Array = [
	"walk_up_1", "walk_up_2", "attack_up",
	"walk_down_1", "walk_down_2", "attack_down",
	"walk_left_1", "walk_left_2", "attack_left",
	"walk_right_1", "walk_right_2", "attack_right"
]


func initialize(grid: GridContainer, scroll: ScrollContainer) -> bool:
	grid_container = grid
	scroll_container = scroll

	if not grid_container or not scroll_container:
		push_error("[SpriteGrid] Missing UI references")
		return false

	grid_container.mouse_filter = Control.MOUSE_FILTER_PASS
	return true


func load_atlas_textures() -> bool:
	"""Load the sprite atlas sheets"""
	status_changed.emit("Loading atlas textures...")

	atlas_textures.clear()
	var atlas1 = load("res://assets-odyssey/sprites_part1.png")
	var atlas2 = load("res://assets-odyssey/sprites_part2.png")

	if not atlas1 or not atlas2:
		status_changed.emit("ERROR: Could not load sprite atlas files")
		return false

	atlas_textures.append(atlas1)
	atlas_textures.append(atlas2)
	return true


func load_character_sprites():
	"""Initialize sprite regions and display grid"""
	if not load_atlas_textures():
		return

	# Generate sprite region list - ONLY PREVIEW SPRITES (column 3)
	sprite_regions.clear()
	for row in range(CHARACTER_ROWS):
		var col = PREVIEW_COL
		var atlas_index = 0 if row < ROWS_PER_ATLAS else 1
		var local_row = row if row < ROWS_PER_ATLAS else row - ROWS_PER_ATLAS

		sprite_regions.append({
			"row": row,
			"col": col,
			"atlas_index": atlas_index,
			"local_row": local_row
		})

	total_pages = int(ceil(float(CHARACTER_ROWS) / float(rows_per_page)))
	current_page = 0

	display_sprite_grid()
	status_changed.emit("Ready: %d characters available. Click to auto-assign." % CHARACTER_ROWS)


func display_sprite_grid():
	"""Create buttons for current page"""
	# Clear existing
	for child in grid_container.get_children():
		child.queue_free()

	loaded_buttons.clear()

	# Calculate page bounds
	var start_row = current_page * rows_per_page
	var end_row = min(start_row + rows_per_page, CHARACTER_ROWS)
	var start_index = start_row
	var end_index = end_row

	# Create placeholder buttons
	for i in range(start_index, end_index):
		if i >= sprite_regions.size():
			break

		var region = sprite_regions[i]
		var sprite_button = TextureButton.new()
		sprite_button.custom_minimum_size = Vector2(64, 64)
		sprite_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		sprite_button.tooltip_text = "Row %d" % region.row
		sprite_button.name = "SpriteButton" + str(i)
		sprite_button.set_meta("sprite_index", i)
		sprite_button.gui_input.connect(_on_sprite_gui_input.bind(i))

		grid_container.add_child(sprite_button)


func load_visible_sprites():
	"""Load textures only for visible sprites (lazy loading)"""
	if not scroll_container or not grid_container:
		return

	var viewport_rect = scroll_container.get_global_rect()

	for button in grid_container.get_children():
		var sprite_index = button.get_meta("sprite_index", -1)
		if sprite_index == -1:
			continue

		var button_rect = button.get_global_rect()
		if viewport_rect.intersects(button_rect):
			# Load if visible and not loaded
			if not loaded_buttons.has(sprite_index):
				var texture = get_sprite_texture(sprite_index)
				if texture:
					button.texture_normal = texture
					loaded_buttons[sprite_index] = true
		else:
			# Unload if scrolled out of view
			if loaded_buttons.has(sprite_index):
				button.texture_normal = null
				loaded_buttons.erase(sprite_index)


func get_sprite_texture(sprite_index: int) -> Texture2D:
	"""Create AtlasTexture from sprite region with caching"""
	if sprite_index < 0 or sprite_index >= sprite_regions.size():
		return null

	var region = sprite_regions[sprite_index]
	return get_sprite_texture_from_data(region)


func get_sprite_texture_from_data(sprite_data: Dictionary) -> Texture2D:
	"""Create AtlasTexture from sprite data dictionary"""
	var atlas_index = sprite_data.get("atlas_index", 0)
	var row = sprite_data.get("row", 0)
	var col = sprite_data.get("col", 0)
	var local_row = sprite_data.get("local_row", row if row < ROWS_PER_ATLAS else row - ROWS_PER_ATLAS)

	var cache_key = "%d_%d_%d" % [atlas_index, row, col]

	if not sprite_cache.has(cache_key):
		if atlas_index >= atlas_textures.size():
			return null

		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = atlas_textures[atlas_index]

		var x = col * SPRITE_SIZE
		var y = local_row * SPRITE_SIZE

		atlas_tex.region = Rect2(
			x + CROP_EDGE,
			y + CROP_EDGE,
			SPRITE_SIZE - (CROP_EDGE * 2),
			SPRITE_SIZE - (CROP_EDGE * 2)
		)
		sprite_cache[cache_key] = atlas_tex

	return sprite_cache[cache_key]


func _on_sprite_gui_input(event: InputEvent, sprite_index: int):
	"""Handle click on sprite - selects entire row"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selection_start = sprite_index
			_update_selected_sprites_list()

			var region = sprite_regions[sprite_index]

			if selected_sprites.size() == 12:
				# Emit signal with full row data
				sprite_row_selected.emit(region["row"], selected_sprites.duplicate())
				status_changed.emit("Selected row %d - 12 sprites ready" % region["row"])

				# Clear selection after emit
				selected_sprites.clear()
				selection_start = -1
			else:
				status_changed.emit("Selected %d sprites (incomplete row)" % selected_sprites.size())


func _update_selected_sprites_list():
	"""Build list of all 12 sprites in clicked row"""
	# Clear previous highlights
	for button in grid_container.get_children():
		button.modulate = Color.WHITE

	selected_sprites.clear()
	if selection_start < 0 or selection_start >= sprite_regions.size():
		return

	var region = sprite_regions[selection_start]
	var clicked_row = region["row"]

	# Build full row (12 sprites)
	for col in range(COLS_PER_ROW):
		var atlas_index = 0 if clicked_row < ROWS_PER_ATLAS else 1
		var local_row = clicked_row if clicked_row < ROWS_PER_ATLAS else clicked_row - ROWS_PER_ATLAS

		selected_sprites.append({
			"row": clicked_row,
			"col": col,
			"atlas_index": atlas_index,
			"local_row": local_row
		})

	# Highlight clicked button
	if selection_start < grid_container.get_child_count():
		var button = grid_container.get_child(selection_start - (current_page * rows_per_page))
		if button:
			button.modulate = Color(0.5, 1.0, 0.5, 1.0)


func next_page():
	if current_page < total_pages - 1:
		current_page += 1
		display_sprite_grid()


func prev_page():
	if current_page > 0:
		current_page -= 1
		display_sprite_grid()


func get_page_info() -> Dictionary:
	var start_row = current_page * rows_per_page
	var end_row = min(start_row + rows_per_page, CHARACTER_ROWS)
	return {
		"current": current_page + 1,
		"total": total_pages,
		"start_row": start_row,
		"end_row": end_row - 1,
		"total_rows": CHARACTER_ROWS
	}
