extends Node
## Autoload singleton - access via DeveloperToolsService

var http_request: HTTPRequest

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)


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

const REMOTE_SERVER_IP = "178.156.202.89"
const ADMIN_PORT = 9124
const ADMIN_ENDPOINT = "/admin/update"
const ADMIN_TOKEN = "ODY-2024-a9f3b7c2e8d1f4a6-ADMIN-KEY"

func deploy_to_remote(project_root: String):
	print("Triggering Remote Server Update...")

	var url = "http://%s:%d%s" % [REMOTE_SERVER_IP, ADMIN_PORT, ADMIN_ENDPOINT]
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + ADMIN_TOKEN
	]
	var body = JSON.stringify({"admin_token": ADMIN_TOKEN}) # Send token in body as well, just in case

	print("Sending POST request to: %s" % url)
	print("Body: %s" % body)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)

	if error != OK:
		printerr("Failed to send update request: %s" % error)
		return

	var result = await http_request.request_completed
	var status_code = result[1]
	var response_body = result[3].get_string_from_utf8()

	if status_code == 200:
		print("Server Update Triggered: %s" % response_body)
		OS.alert("Server Update Initiated Successfully!\nThe server is now pulling the latest code and will restart momentarily.", "Update Success")
	else:
		printerr("Server Update Request Failed: Status %d, Response: %s" % [status_code, response_body])
		OS.alert("Server Update Failed.\nStatus: %d\nResponse: %s\n\nIs the server running and is AdminManager listening?" % [status_code, response_body], "Update Error")

func deploy_client_dev(project_root: String):
	print("Triggering Dev Client Build via GitHub...")
	_trigger_github_build("Dev Client")

func deploy_client_production(project_root: String):
	print("Triggering Production Client Build via GitHub...")
	_trigger_github_build("Production Client")

func _trigger_github_build(build_name: String):
	# This function commits any pending changes and pushes to main
	# which triggers the GitHub Action to build and deploy.
	
	print("Staging and committing changes...")
	OS.execute("git", ["add", "."], [], true)
	OS.execute("git", ["commit", "-m", "chore: Trigger %s build via DevTools" % build_name], [], true)
	
	print("Pushing to GitHub...")
	var output = []
	var exit_code = OS.execute("git", ["push", "origin", "main"], output, true)
	
	if exit_code == 0:
		OS.alert("%s Build Triggered!\nChanges pushed to GitHub.\nWait for the build to complete on GitHub Actions." % build_name, "Deployment Started")
	else:
		printerr("Git Push Failed: ", output)
		OS.alert("Failed to push changes to GitHub.\nCheck the console/logs for details.", "Deployment Error")