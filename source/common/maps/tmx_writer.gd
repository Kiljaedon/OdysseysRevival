class_name TMXWriter extends RefCounted

## Utility for safely modifying TMX files.
## Handles updating object properties and layer data (for collision carving) without corrupting XML structure.

static func update_warp_target(tmx_path: String, object_id: int, target_map: String, target_x: int, target_y: int) -> bool:
	var content = _read_file(tmx_path)
	if content.is_empty():
		return false
	
	# Regex to find the specific object by ID
	# Pattern looks for <object id="123" ...> and captures content until </object> or />
	var regex = RegEx.new()
	regex.compile('<object[^>]*id="%d"[^>]*>(.*?)(</object>|/>)' % object_id)
	
	var match = regex.search(content)
	if not match:
		push_error("TMXWriter: Object ID %d not found in %s" % [object_id, tmx_path])
		return false
		
	var object_tag = match.get_string(0)
	
	# We need to ensure the properties exist
	var updated_tag = _upsert_property(object_tag, "target_map", target_map)
	updated_tag = _upsert_property(updated_tag, "target_x", str(target_x))
	updated_tag = _upsert_property(updated_tag, "target_y", str(target_y))
	
	# Replace in content
	var new_content = content.replace(object_tag, updated_tag)
	return _write_file(tmx_path, new_content)

static func _upsert_property(object_tag: String, prop_name: String, prop_value: String) -> String:
	# Check if property exists
	var regex = RegEx.new()
	regex.compile('<property[^>]*name="%s"[^>]*value="[^"]*"' % prop_name)
	
	var existing_prop = regex.search(object_tag)
	
	if existing_prop:
		# Replace existing value
		var old_prop_str = existing_prop.get_string(0)
		var new_prop_str = '<property name="%s" value="%s"' % [prop_name, prop_value] # Intentionally open to match regex loose end
		# Actually safer to rebuild the whole tag
		var full_old_prop_regex = RegEx.new()
		full_old_prop_regex.compile('<property[^>]*name="%s"[^>]*value="[^"]*"[^>]*/>' % prop_name)
		var full_match = full_old_prop_regex.search(object_tag)
		if full_match:
			var replacement = '<property name="%s" value="%s"/>' % [prop_name, prop_value]
			return object_tag.replace(full_match.get_string(0), replacement)
		return object_tag # Fallback if regex weirdness
	else:
		# Insert new property
		# Look for <properties> block
		if "<properties>" in object_tag:
			var new_prop = '\n   <property name="%s" value="%s"/>' % [prop_name, prop_value]
			return object_tag.replace("<properties>", "<properties>" + new_prop)
		else:
			# Create properties block if object is not self-closing or inject before close
			if "/>" in object_tag:
				# Self closing: <object ... /> -> <object ...><properties>...</properties></object>
				var new_block = '>\n  <properties>\n   <property name="%s" value="%s"/>\n  </properties>\n </object>' % [prop_name, prop_value]
				return object_tag.replace("/>", new_block)
			else:
				# Open tag: <object ...> ... </object>
				var new_block = '<properties>\n   <property name="%s" value="%s"/>\n  </properties>' % [prop_name, prop_value]
				# Insert after opening tag end
				var first_close_bracket = object_tag.find(">")
				return object_tag.insert(first_close_bracket + 1, "\n  " + new_block)

static func carve_collision(tmx_path: String, area_rect: Rect2, tile_width: int = 32, tile_height: int = 32) -> bool:
	var content = _read_file(tmx_path)
	if content.is_empty():
		return false

	# 1. Parse Map Dimensions
	var width_regex = RegEx.new()
	width_regex.compile('width="(\\d+)"')
	var height_regex = RegEx.new()
	height_regex.compile('height="(\\d+)"')
	
	var map_width = width_regex.search(content).get_string(1).to_int()
	# var map_height = height_regex.search(content).get_string(1).to_int()

	# 2. Locate Layers
	var middle_layer_regex = RegEx.new()
	# Tiled layers often look like: <layer id="2" name="Middle" width="X" height="Y"> ... <data encoding="csv"> ... </data>
	# We capture the CSV content
	middle_layer_regex.compile('<layer[^>]*name="[^"]*Middle[^"]*"[^>]*>[\\s\\S]*?<data[^>]*encoding="csv">([\\s\\S]*?)</data>')
	var bottom_layer_regex = RegEx.new()
	bottom_layer_regex.compile('<layer[^>]*name="[^"]*Bottom[^"]*"[^>]*>[\\s\\S]*?<data[^>]*encoding="csv">([\\s\\S]*?)</data>')

	var middle_match = middle_layer_regex.search(content)
	var bottom_match = bottom_layer_regex.search(content)

	if not middle_match:
		push_error("TMXWriter: Middle layer not found for carving")
		return false

	# If bottom layer doesn't exist, we can't move tiles there (simplification: require it exists)
	if not bottom_match:
		push_error("TMXWriter: Bottom layer not found for carving (required destination)")
		return false

	# 3. Parse CSV to Arrays
	var middle_csv = middle_match.get_string(1).strip_edges()
	var bottom_csv = bottom_match.get_string(1).strip_edges()
	
	var middle_data = _csv_to_array(middle_csv)
	var bottom_data = _csv_to_array(bottom_csv)

	if middle_data.size() != bottom_data.size():
		push_error("TMXWriter: Layer size mismatch")
		return false

	# 4. Perform the Swap
	# area_rect is in pixels, convert to tile coords
	var start_x = int(area_rect.position.x / tile_width)
	var start_y = int(area_rect.position.y / tile_height)
	var end_x = int((area_rect.position.x + area_rect.size.x) / tile_width)
	var end_y = int((area_rect.position.y + area_rect.size.y) / tile_height)

	var changes_made = false

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var idx = y * map_width + x
			if idx >= 0 and idx < middle_data.size():
				var tile_gid = middle_data[idx]
				if tile_gid != 0:
					# Move to bottom
					bottom_data[idx] = tile_gid # Overwrite whatever was on bottom (grass) with wall? 
					# TODO: This might overwrite ground. Ideally we need a "Decoration" layer or "Underlay".
					# For now, per user request "leave bottom layer", maybe we just INSERT if bottom is 0?
					# User said: "auto clear collision map art... but leave bottom layer"
					# Interpretation: "Middle" has the wall. "Bottom" has the floor.
					# We want to REMOVE wall from Middle.
					# But we want to KEEP the wall visual. So we must put the wall SOMEWHERE.
					# Putting wall on Bottom overwrites floor. Bad.
					# We need a new layer or swap to "Fringe"? 
					# Let's assume "Bottom" is the destination for now as requested, but be careful.
					# BETTER: User meant "Clear collision art (Middle) but leave bottom layer (the floor underneath)".
					# This implies the wall art is deleted? "Fix it graphically then".
					# Ah, "I can go back to the map editor and fix it graphically".
					# So my job is just to CLEAR the collision (Middle layer).
					
					# Wait, "clear collision map art... but leave bottom layer".
					# If I clear Middle, the wall art disappears. The collision disappears. The floor (Bottom) remains.
					# This seems to be what is asked. "Auto clear... art... leave bottom".
					
					middle_data[idx] = 0
					changes_made = true

	if not changes_made:
		return true

	# 5. Reconstruct CSV
	var new_middle_csv = _array_to_csv(middle_data, map_width)
	
	# 6. Replace in Content
	# We only modified middle data
	var new_content = content.replace(middle_csv, new_middle_csv)
	
	return _write_file(tmx_path, new_content)

static func _csv_to_array(csv: String) -> Array[int]:
	var arr: Array[int] = []
	var clean = csv.replace("\n", "").replace("\r", "")
	for s in clean.split(","):
		if s.strip_edges() != "":
			arr.append(s.to_int())
	return arr

static func _array_to_csv(data: Array[int], width: int) -> String:
	var s = "\n"
	for i in range(data.size()):
		s += str(data[i]) + ","
		if (i + 1) % width == 0:
			s += "\n"
	return s.trim_suffix(",").trim_suffix("\n") + "\n"


static func _read_file(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to read: " + path)
		return ""
	return file.get_as_text()

static func _write_file(path: String, content: String) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to write: " + path)
		return false
	file.store_string(content)
	return true
