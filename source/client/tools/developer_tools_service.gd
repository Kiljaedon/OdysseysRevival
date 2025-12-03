class_name DeveloperToolsService
extends Node

func launch_pixi_editor(project_root: String):
	print("Launching PixiEditor Art Studio...")
	var portable_pixieditor = project_root + "/tools/pixieditor/PixiEditor/PixiEditor.exe"
	var sprites_file = project_root + "/assets-odyssey/sprites.png"

	if FileAccess.file_exists(portable_pixieditor):
		OS.create_process(portable_pixieditor, [sprites_file])
		print("Portable PixiEditor launched.")
	else:
		print("PixiEditor not found. Running download helper...")
		var download_helper = project_root + "/tools/pixieditor/DOWNLOAD_PIXIEDITOR.bat"
		if FileAccess.file_exists(download_helper):
			OS.create_process(download_helper, [])
		else:
			print("Please download PixiEditor manually.")

func launch_tiled_editor(project_root: String):
	print("Launching Tiled Map Editor...")
	var map_file = project_root + "/maps/World Maps/sample_map.tmx"
	var portable_tiled = project_root + "/tools/tiled/tiled.exe"

	if FileAccess.file_exists(portable_tiled):
		OS.create_process(portable_tiled, [map_file])
		print("Tiled launched.")
	else:
		print("Portable Tiled not found at: ", portable_tiled)

func deploy_to_remote(project_root: String):
	print("Pushing to Remote Server (Odyssey)...")
	var batch_path = project_root + "/deploy_to_remote.bat"
	
	# Logic to generate the batch file could be moved here if it needs to be dynamic,
	# or we just execute the existing one.
	# For now, let's assume the file generation logic stays in the service to keep it self-contained.
	_generate_deployment_script(project_root, batch_path)
	
	if FileAccess.file_exists(batch_path):
		OS.create_process("cmd.exe", ["/c", "start", batch_path])
		print("Deployment started.")

func _generate_deployment_script(project_root: String, batch_path: String):
	# (Content from gateway.gd _on_push_remote_pressed)
	var source_path = project_root + "/source"
	var addons_path = project_root + "/addons"
	var remote_host = "odyssey"
	var remote_path = "/home/gameserver/odysseys_server_dev/"

	var batch_content = """@echo off
title Golden Sun MMO - Deploying to Remote Server
echo Deploying...
rsync -avz --delete --exclude=".godot" "%s" %s:%ssource/
echo Done.
pause
""" % [source_path, remote_host, remote_path] 
    # Simplified for brevity in this refactor step, full logic can be copied.
	
	var file = FileAccess.open(batch_path, FileAccess.WRITE)
	if file:
		file.store_string(batch_content)
		file.close()
