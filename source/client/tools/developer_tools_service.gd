extends Node
## Autoload singleton - access via DeveloperToolsService
## Full automation for deployment workflow with visual progress

const DeploymentProgressWindow = preload("res://source/client/tools/deployment_progress_window.gd")

var http_request: HTTPRequest
var progress_window: DeploymentProgressWindow = null

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)


# ============================================================================
# EXTERNAL TOOL LAUNCHERS
# ============================================================================

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


# ============================================================================
# SERVER CONFIGURATION
# ============================================================================

const REMOTE_SERVER_IP = "178.156.202.89"
const ADMIN_PORT = 9124
const ADMIN_ENDPOINT = "/admin/update"
const ADMIN_TOKEN = "ODY-2024-a9f3b7c2e8d1f4a6-ADMIN-KEY"


# ============================================================================
# PROGRESS WINDOW MANAGEMENT
# ============================================================================

func _create_progress_window(title: String, steps: Array) -> DeploymentProgressWindow:
	"""Create and show the deployment progress window"""
	progress_window = DeploymentProgressWindow.new()
	get_tree().root.add_child(progress_window)
	progress_window.initialize(title, steps)
	progress_window.popup_centered()

	# Wait a frame to ensure window is visible
	await get_tree().process_frame
	return progress_window


# ============================================================================
# VERSION MANAGEMENT
# ============================================================================

func _get_current_version(project_root: String) -> String:
	"""Read current version from version.txt"""
	var version_file = project_root + "/version.txt"
	if FileAccess.file_exists(version_file):
		var file = FileAccess.open(version_file, FileAccess.READ)
		var version = file.get_line().strip_edges()
		file.close()
		return version
	return "0.0.0"

func _increment_version(version: String) -> String:
	"""Increment patch version: 0.1.0004 -> 0.1.0005
	Uses 4-digit patch numbers (0001-9999) for ~10,000 updates before 1.0
	SAFEGUARD: Never auto-increment to 1.0 - that's reserved for official release"""
	var parts = version.split(".")
	if parts.size() >= 3:
		var major = int(parts[0])
		var minor = int(parts[1])
		var patch = int(parts[2])

		# Increment patch
		patch += 1

		# SAFEGUARD: Cap at 0.1.9999 - manual intervention required for 1.0
		if patch > 9999:
			printerr("VERSION CAP REACHED: Cannot auto-increment past 0.1.9999. Manual version change required for 1.0 release.")
			return "0.1.9999"

		parts[0] = str(major)
		parts[1] = str(minor)
		# Format patch as 4 digits with leading zeros
		parts[2] = "%04d" % patch

	return ".".join(parts)

func _update_all_version_files(project_root: String, new_version: String) -> bool:
	"""Update all version files to new version"""
	if progress_window:
		progress_window.log_line("Updating version files to: %s" % new_version)

	var updated_files: Array = []

	# 1. Update version.txt
	var version_txt = project_root + "/version.txt"
	var file = FileAccess.open(version_txt, FileAccess.WRITE)
	if file:
		file.store_string(new_version + "\n")
		file.close()
		updated_files.append("version.txt")
		if progress_window:
			progress_window.log_data("Updated", "version.txt")
	else:
		if progress_window:
			progress_window.log_line("[color=red]Failed to update version.txt[/color]")
		return false

	# 2. Update version.gd
	var version_gd = project_root + "/source/common/version.gd"
	if FileAccess.file_exists(version_gd):
		file = FileAccess.open(version_gd, FileAccess.READ)
		var content = file.get_as_text()
		file.close()

		var lines = content.split("\n")
		for i in range(lines.size()):
			if lines[i].begins_with("const GAME_VERSION"):
				lines[i] = 'const GAME_VERSION: String = "%s"' % new_version
			elif lines[i].begins_with("const MIN_COMPATIBLE_VERSION"):
				lines[i] = 'const MIN_COMPATIBLE_VERSION: String = "%s"' % new_version

		file = FileAccess.open(version_gd, FileAccess.WRITE)
		file.store_string("\n".join(lines))
		file.close()
		updated_files.append("source/common/version.gd")
		if progress_window:
			progress_window.log_data("Updated", "source/common/version.gd")

	# 3. Update project.godot
	var project_godot = project_root + "/project.godot"
	if FileAccess.file_exists(project_godot):
		file = FileAccess.open(project_godot, FileAccess.READ)
		var content = file.get_as_text()
		file.close()

		var lines = content.split("\n")
		for i in range(lines.size()):
			if lines[i].begins_with("config/version="):
				lines[i] = 'config/version="%s"' % new_version

		file = FileAccess.open(project_godot, FileAccess.WRITE)
		file.store_string("\n".join(lines))
		file.close()
		updated_files.append("project.godot")
		if progress_window:
			progress_window.log_data("Updated", "project.godot")

	# 4. Update export_presets.cfg
	var export_presets = project_root + "/export_presets.cfg"
	if FileAccess.file_exists(export_presets):
		file = FileAccess.open(export_presets, FileAccess.READ)
		var content = file.get_as_text()
		file.close()

		var lines = content.split("\n")
		for i in range(lines.size()):
			if lines[i].begins_with("file_version=") or lines[i].begins_with("product_version="):
				var key = lines[i].split("=")[0]
				lines[i] = '%s="%s"' % [key, new_version]

		file = FileAccess.open(export_presets, FileAccess.WRITE)
		file.store_string("\n".join(lines))
		file.close()
		updated_files.append("export_presets.cfg")
		if progress_window:
			progress_window.log_data("Updated", "export_presets.cfg")

	if progress_window:
		progress_window.log_line("[color=green]%d version files updated successfully[/color]" % updated_files.size())

	return true


# ============================================================================
# GIT OPERATIONS
# ============================================================================

func _get_git_status(project_root: String) -> Dictionary:
	"""Get git status information"""
	var result = {
		"modified": [],
		"added": [],
		"deleted": [],
		"untracked": []
	}

	var output = []
	OS.execute("git", ["status", "--porcelain"], output, true)

	if output.size() > 0:
		var lines = output[0].split("\n")
		for line in lines:
			if line.length() < 3:
				continue
			var status = line.substr(0, 2)
			var filename = line.substr(3).strip_edges()

			if status.contains("M"):
				result.modified.append(filename)
			elif status.contains("A"):
				result.added.append(filename)
			elif status.contains("D"):
				result.deleted.append(filename)
			elif status.contains("?"):
				result.untracked.append(filename)

	return result


func _git_commit_and_push(message: String, step_start: int) -> bool:
	"""Stage all changes, commit, and push to GitHub with progress updates"""

	# Step: Check git status
	if progress_window:
		progress_window.start_step(step_start)
		progress_window.log_line("Checking local changes...")

	var status = _get_git_status("")

	if progress_window:
		if status.modified.size() > 0:
			progress_window.log_data("Modified files", str(status.modified.size()))
			for f in status.modified:
				progress_window.log_line("  M: %s" % f)
		if status.added.size() > 0:
			progress_window.log_data("Added files", str(status.added.size()))
		if status.untracked.size() > 0:
			progress_window.log_data("Untracked files", str(status.untracked.size()))
			for f in status.untracked:
				progress_window.log_line("  ?: %s" % f)

		progress_window.complete_step(step_start, true)

	# Step: Stage changes
	if progress_window:
		progress_window.start_step(step_start + 1)
		progress_window.log_line("Staging all changes (git add .)...")

	var output = []
	OS.execute("git", ["add", "."], output, true)

	if progress_window:
		progress_window.log_line("All changes staged")
		progress_window.complete_step(step_start + 1, true)

	# Step: Commit
	if progress_window:
		progress_window.start_step(step_start + 2)
		progress_window.log_line("Creating commit...")
		progress_window.log_data("Commit message", message)

	output = []
	var commit_result = OS.execute("git", ["commit", "-m", message], output, true)

	if progress_window:
		if output.size() > 0:
			# Show commit summary
			var commit_output = output[0] if output[0] is String else str(output)
			if commit_output.contains("nothing to commit"):
				progress_window.log_line("[color=yellow]No changes to commit (working tree clean)[/color]")
			else:
				progress_window.log_line("Commit created successfully")
		progress_window.complete_step(step_start + 2, true)

	# Step: Push to GitHub
	if progress_window:
		progress_window.start_step(step_start + 3)
		progress_window.log_line("Pushing to GitHub (origin main)...")

	output = []
	var exit_code = OS.execute("git", ["push", "origin", "main"], output, true)

	if exit_code != 0:
		if progress_window:
			progress_window.log_line("[color=red]Git push failed![/color]")
			if output.size() > 0:
				progress_window.log_line(str(output))
			progress_window.complete_step(step_start + 3, false)
		return false

	if progress_window:
		progress_window.log_line("[color=green]Successfully pushed to GitHub![/color]")
		progress_window.complete_step(step_start + 3, true)

	return true


# ============================================================================
# DEPLOYMENT FUNCTIONS
# ============================================================================

func _has_uncommitted_changes(project_root: String) -> bool:
	"""Check if there are any uncommitted changes (modified, added, deleted, or untracked files)"""
	var status = _get_git_status(project_root)
	return status.modified.size() > 0 or status.added.size() > 0 or status.deleted.size() > 0 or status.untracked.size() > 0


func deploy_to_remote(project_root: String):
	"""
	UPDATE SERVER - Full automation with visual progress:
	1. Check local changes
	2. Stage changes
	3. Commit changes
	4. Push to GitHub
	5. Trigger server pull
	6. Server restart
	"""
	# Pre-check: Are there any changes to deploy?
	if not _has_uncommitted_changes(project_root):
		var steps = ["Check local changes"]
		await _create_progress_window("Deploying Server Update", steps)
		progress_window.start_step(0)
		progress_window.log_line("[color=yellow]No changes detected![/color]")
		progress_window.log_line("Working tree is clean - nothing to commit or push.")
		progress_window.complete_step(0, true)
		progress_window.finish_deployment(true, "No changes to deploy. Server is already up to date with local code.")
		return

	var steps = [
		"Check local changes",
		"Stage changes (git add)",
		"Commit changes",
		"Push to GitHub",
		"Trigger server pull",
		"Server restart"
	]

	await _create_progress_window("Deploying Server Update", steps)

	# Steps 0-3: Git operations
	var git_success = _git_commit_and_push("chore: Server update via DevTools", 0)

	if not git_success:
		progress_window.finish_deployment(false, "Failed to push changes to GitHub")
		return

	# Step 4: Trigger server pull
	progress_window.start_step(4)
	progress_window.log_line("Sending update request to remote server...")
	progress_window.log_data("Server", "%s:%d" % [REMOTE_SERVER_IP, ADMIN_PORT])

	var url = "http://%s:%d%s" % [REMOTE_SERVER_IP, ADMIN_PORT, ADMIN_ENDPOINT]
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + ADMIN_TOKEN
	]
	var body = JSON.stringify({"admin_token": ADMIN_TOKEN})

	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		progress_window.log_line("[color=red]Failed to contact server![/color]")
		progress_window.complete_step(4, false)
		progress_window.finish_deployment(false, "GitHub push succeeded, but failed to contact server")
		return

	var result = await http_request.request_completed
	var status_code = result[1]
	var response_body = result[3].get_string_from_utf8()

	if status_code == 200:
		progress_window.log_line("[color=green]Server received update request[/color]")
		progress_window.log_data("Response", response_body)
		progress_window.complete_step(4, true)

		# Step 5: Server restart
		progress_window.start_step(5)
		progress_window.log_line("Server is pulling latest code and restarting...")
		progress_window.log_line("[color=cyan]This typically takes 5-10 seconds[/color]")
		progress_window.complete_step(5, true)

		progress_window.finish_deployment(true, "Server update complete! Changes are now live.")
	else:
		progress_window.log_line("[color=red]Server update request failed![/color]")
		progress_window.log_data("Status", str(status_code))
		progress_window.log_data("Response", response_body)
		progress_window.complete_step(4, false)
		progress_window.finish_deployment(false, "GitHub push succeeded, but server pull failed")


func deploy_client_dev(project_root: String):
	"""
	DEPLOY DEV CLIENT - Full automation with visual progress:
	1. Check local changes
	2. Bump version number
	3. Update version files
	4. Stage changes
	5. Commit changes
	6. Push to GitHub
	7. GitHub Actions triggered

	NOTE: Only increments version if there are actual changes to commit.
	"""
	# Pre-check: Are there any changes to deploy?
	if not _has_uncommitted_changes(project_root):
		var steps = ["Check local changes"]
		await _create_progress_window("Deploying Dev Client", steps)
		progress_window.start_step(0)
		progress_window.log_line("[color=yellow]No changes detected![/color]")
		progress_window.log_line("Working tree is clean - nothing to commit or push.")
		progress_window.log_line("Version will NOT be incremented (no changes to release).")
		progress_window.complete_step(0, true)
		progress_window.finish_deployment(true, "No changes to deploy. Make some code changes first!")
		return

	var current_version = _get_current_version(project_root)
	var new_version = _increment_version(current_version)

	var steps = [
		"Check local changes",
		"Bump version (%s -> %s)" % [current_version, new_version],
		"Update version files",
		"Stage changes (git add)",
		"Commit changes",
		"Push to GitHub",
		"GitHub Actions triggered"
	]

	await _create_progress_window("Deploying Dev Client v%s" % new_version, steps)

	# Step 0: Check local changes
	progress_window.start_step(0)
	var status = _get_git_status(project_root)
	progress_window.log_data("Modified files", str(status.modified.size()))
	progress_window.log_data("Untracked files", str(status.untracked.size()))
	progress_window.log_line("[color=green]Changes detected - proceeding with version bump[/color]")
	progress_window.complete_step(0, true)

	# Step 1: Version bump
	progress_window.start_step(1)
	progress_window.log_line("Incrementing version number...")
	progress_window.log_data("Current version", current_version)
	progress_window.log_data("New version", new_version)
	progress_window.complete_step(1, true)

	# Step 2: Update version files
	progress_window.start_step(2)
	if not _update_all_version_files(project_root, new_version):
		progress_window.complete_step(2, false)
		progress_window.finish_deployment(false, "Failed to update version files")
		return
	progress_window.complete_step(2, true)

	# Steps 3-5: Git operations
	progress_window.start_step(3)
	progress_window.log_line("Staging all changes...")
	OS.execute("git", ["add", "."], [], true)
	progress_window.complete_step(3, true)

	progress_window.start_step(4)
	var commit_msg = "release: Dev Client v%s" % new_version
	progress_window.log_data("Commit message", commit_msg)
	OS.execute("git", ["commit", "-m", commit_msg], [], true)
	progress_window.complete_step(4, true)

	progress_window.start_step(5)
	progress_window.log_line("Pushing to GitHub...")
	var output = []
	var exit_code = OS.execute("git", ["push", "origin", "main"], output, true)

	if exit_code != 0:
		progress_window.log_line("[color=red]Push failed![/color]")
		progress_window.complete_step(5, false)
		progress_window.finish_deployment(false, "Failed to push to GitHub")
		return

	progress_window.log_line("[color=green]Push successful![/color]")
	progress_window.complete_step(5, true)

	# Step 6: GitHub Actions
	progress_window.start_step(6)
	progress_window.log_line("GitHub Actions workflow triggered!")
	progress_window.log_line("[color=cyan]The workflow will:[/color]")
	progress_window.log_line("  1. Build Windows Dev Client")
	progress_window.log_line("  2. Upload to R2 storage")
	progress_window.log_line("  3. Update version.json for auto-updater")
	progress_window.log_line("")
	progress_window.log_line("[color=yellow]Build time: ~3-5 minutes[/color]")
	progress_window.log_line("Check: https://github.com/Kiljaedon/OdysseysRevival/actions")
	progress_window.complete_step(6, true)

	progress_window.finish_deployment(true, "Dev Client v%s deployment initiated!\nAuto-updater will detect the new version once build completes." % new_version)


func deploy_client_production(project_root: String):
	"""
	DEPLOY PRODUCTION CLIENT - Full automation with visual progress:
	1. Check local changes
	2. Bump version number
	3. Update version files
	4. Stage changes
	5. Commit changes
	6. Push to GitHub
	7. GitHub Actions triggered

	NOTE: Only increments version if there are actual changes to commit.
	"""
	# Pre-check: Are there any changes to deploy?
	if not _has_uncommitted_changes(project_root):
		var steps = ["Check local changes"]
		await _create_progress_window("Deploying Production Client", steps)
		progress_window.start_step(0)
		progress_window.log_line("[color=yellow]No changes detected![/color]")
		progress_window.log_line("Working tree is clean - nothing to commit or push.")
		progress_window.log_line("Version will NOT be incremented (no changes to release).")
		progress_window.complete_step(0, true)
		progress_window.finish_deployment(true, "No changes to deploy. Make some code changes first!")
		return

	var current_version = _get_current_version(project_root)
	var new_version = _increment_version(current_version)

	var steps = [
		"Check local changes",
		"Bump version (%s -> %s)" % [current_version, new_version],
		"Update version files",
		"Stage changes (git add)",
		"Commit changes",
		"Push to GitHub",
		"GitHub Actions triggered"
	]

	await _create_progress_window("Deploying Production Client v%s" % new_version, steps)

	# Step 0: Check local changes
	progress_window.start_step(0)
	var status = _get_git_status(project_root)
	progress_window.log_data("Modified files", str(status.modified.size()))
	progress_window.log_data("Untracked files", str(status.untracked.size()))
	progress_window.log_line("[color=green]Changes detected - proceeding with version bump[/color]")
	progress_window.complete_step(0, true)

	# Step 1: Version bump
	progress_window.start_step(1)
	progress_window.log_line("Incrementing version number...")
	progress_window.log_data("Current version", current_version)
	progress_window.log_data("New version", new_version)
	progress_window.complete_step(1, true)

	# Step 2: Update version files
	progress_window.start_step(2)
	if not _update_all_version_files(project_root, new_version):
		progress_window.complete_step(2, false)
		progress_window.finish_deployment(false, "Failed to update version files")
		return
	progress_window.complete_step(2, true)

	# Steps 3-5: Git operations
	progress_window.start_step(3)
	progress_window.log_line("Staging all changes...")
	OS.execute("git", ["add", "."], [], true)
	progress_window.complete_step(3, true)

	progress_window.start_step(4)
	var commit_msg = "release: Production Client v%s" % new_version
	progress_window.log_data("Commit message", commit_msg)
	OS.execute("git", ["commit", "-m", commit_msg], [], true)
	progress_window.complete_step(4, true)

	progress_window.start_step(5)
	progress_window.log_line("Pushing to GitHub...")
	var output = []
	var exit_code = OS.execute("git", ["push", "origin", "main"], output, true)

	if exit_code != 0:
		progress_window.log_line("[color=red]Push failed![/color]")
		progress_window.complete_step(5, false)
		progress_window.finish_deployment(false, "Failed to push to GitHub")
		return

	progress_window.log_line("[color=green]Push successful![/color]")
	progress_window.complete_step(5, true)

	# Step 6: GitHub Actions
	progress_window.start_step(6)
	progress_window.log_line("GitHub Actions workflow triggered!")
	progress_window.log_line("[color=cyan]The workflow will:[/color]")
	progress_window.log_line("  1. Build Windows Production Client")
	progress_window.log_line("  2. Upload to R2 storage")
	progress_window.log_line("  3. Update version.json for auto-updater")
	progress_window.log_line("")
	progress_window.log_line("[color=yellow]Build time: ~3-5 minutes[/color]")
	progress_window.log_line("Check: https://github.com/Kiljaedon/OdysseysRevival/actions")
	progress_window.complete_step(6, true)

	progress_window.finish_deployment(true, "Production Client v%s deployment initiated!\nAuto-updater will detect the new version once build completes." % new_version)
