extends Control

## Map Linker v2 - World Atlas Editor
## Allows linking multiple maps via Drag-and-Drop and visual connections.

@onready var world_canvas: WorldCanvas = $HSplitContainer/CanvasPanel/WorldCanvas
@onready var map_list: ItemList = $HSplitContainer/SidePanel/VBoxContainer/MapList

var world_maps_dir: String = "res://maps/World Maps/"

func _ready():
	_scan_maps()
	map_list.item_activated.connect(_on_map_activated)

func _on_map_activated(index: int):
	var file_name = map_list.get_item_text(index)
	var full_path = world_maps_dir + file_name
	
	if world_canvas:
		# Add at center of view (offset slightly to avoid perfect stacking)
		# We don't know exact center of camera in canvas coords easily without exposing it
		# For now, just add at a random offset near 0,0
		var pos = Vector2(100 + randf() * 50, 100 + randf() * 50)
		world_canvas.add_map(full_path, pos)

func _scan_maps():
	map_list.clear()
	var dir = DirAccess.open(world_maps_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tmx"):
				map_list.add_item(file_name)
				map_list.set_item_tooltip(map_list.item_count - 1, file_name)
			file_name = dir.get_next()

func _get_drag_data(at_position):
	var items = map_list.get_selected_items()
	if items.size() == 0:
		return null
		
	var file_name = map_list.get_item_text(items[0])
	var full_path = world_maps_dir + file_name
	
	# Create drag preview
	var preview = Label.new()
	preview.text = file_name
	set_drag_preview(preview)
	
	return { "files": [full_path] }

func _on_save_pressed():
	if world_canvas:
		world_canvas.save_all()
		# Flash status
		var old_text = $HSplitContainer/SidePanel/VBoxContainer/SaveButton.text
		$HSplitContainer/SidePanel/VBoxContainer/SaveButton.text = "Saved!"
		await get_tree().create_timer(1.0).timeout
		$HSplitContainer/SidePanel/VBoxContainer/SaveButton.text = old_text
