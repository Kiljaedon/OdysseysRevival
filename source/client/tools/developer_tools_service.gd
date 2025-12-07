extends Node
## Autoload singleton - access via DeveloperToolsService

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

func deploy_client_dev(project_root: String):
	print("Launching Dev Client Deployment...")
	var batch_path = project_root + "/deploy_client_dev.bat"
	
	if FileAccess.file_exists(batch_path):
		OS.create_process("cmd.exe", ["/c", "start", batch_path])
		print("Dev Client Deployment started.")
	else:
		printerr("Dev Deployment Batch file not found: ", batch_path)

func deploy_client_production(project_root: String):
	print("Launching Production Client Deployment...")
	var batch_path = project_root + "/deploy_client_production.bat"
	
	if FileAccess.file_exists(batch_path):
		OS.create_process("cmd.exe", ["/c", "start", batch_path])
		print("Production Client Deployment started.")
	else:
		printerr("Production Deployment Batch file not found: ", batch_path)

func _generate_deployment_script(project_root: String, batch_path: String):
	# Configuration
	# We use the SFTP remote defined in rclone.conf
	var rclone_remote = "odyssey_server:/home/gameserver/odysseys_server_dev/source"
	
	var batch_content = """@echo off
title Golden Sun MMO - Deploying to Remote Server (Signal Based)
cd /d "%s"

set RCLONE=tools\\rclone\\rclone.exe
set CONFIG=tools\\rclone\\rclone.conf

echo ========================================
echo STARTING DEPLOYMENT TO: odyssey (Dev)
echo ========================================

echo 1. Syncing source code via Rclone (SFTP)...
"%%RCLONE%%" copy source "odyssey_server:/home/gameserver/odysseys_server_dev/source" --config "%%CONFIG%%" --exclude ".godot/**" --progress

if %%errorlevel%% neq 0 (
    echo.
    echo [ERROR] Rclone sync failed.
    pause
    exit /b %%errorlevel%%
)

echo.
echo 2. Signaling server to restart...
echoRESTART > RESTART_REQUIRED.signal
"%%RCLONE%%" copy RESTART_REQUIRED.signal "odyssey_server:/home/gameserver/odysseys_server_dev/" --config "%%CONFIG%%"
del RESTART_REQUIRED.signal

echo.
echo ========================================
echo DEPLOYMENT SUCCESSFUL
echo ========================================
echo The server watchdog will detect the signal and restart within 5 seconds.
pause
""" % [project_root]
	
	var file = FileAccess.open(batch_path, FileAccess.WRITE)
	if file:
		file.store_string(batch_content)
		file.close()
