extends SceneTree

func _init():
	print("=== DIAGNOSTIC: LISTING CHARACTERS ===")
	
	check_dir("res://characters/classes/")
	check_dir("res://characters/npcs/")
	
	quit()

func check_dir(path):
	print("Checking: ", path)
	var dir = DirAccess.open(path)
	if not dir:
		print("  ERROR: Could not open directory")
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var count = 0
	
	while file_name != "":
		if not dir.current_is_dir():
			print("  File: ", file_name)
			count += 1
		file_name = dir.get_next()
		
	print("  Total files: ", count)
