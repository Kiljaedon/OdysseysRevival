extends Node
class_name AdminManager

const HTTPServer = preload("res://addons/httpserver/http_server.gd")

var http_server: HTTPServer
var admin_token: String = "YOUR_SECRET_ADMIN_TOKEN_HERE" # TODO: Load from config

func _init():
	print("[AdminManager] Initializing HTTP Admin Server.")
	http_server = HTTPServer.new()
	add_child(http_server) # Add as child to ensure _ready() and _physics_process() are called

func _ready():
	# Listen on a dedicated port for admin commands
	var admin_port = 9124 # Configurable port
	var bind_address = "0.0.0.0" # Listen on all interfaces
	
	# The HTTPServer addon might auto-start on 8088 in its _ready().
	# We must stop it first to re-bind to our desired port.
	if http_server.server.is_listening():
		http_server.server.stop()
	
	http_server.server.listen(admin_port, bind_address)
	print("[AdminManager] Admin HTTP Server listening on %s:%d" % [bind_address, admin_port])

	# Register the /admin/update route
	http_server.router.register_route(
		HTTPClient.METHOD_POST,
		"/admin/update",
		Callable(self, "_handle_admin_update")
	)
	print("[AdminManager] Registered /admin/update POST route.")

func _handle_admin_update(payload: Dictionary):
	# Verify admin token from payload or headers (for now, payload for simplicity)
	var received_token = payload.get("admin_token", "")
	if received_token != admin_token:
		printerr("[AdminManager] Unauthorized update attempt (Invalid token).")
		return {"status": "error", "message": "Unauthorized"}

	print("[AdminManager] Admin update request received. Executing update script...")
	
	# Execute the shell script to pull from Git and restart
	var script_path = ProjectSettings.globalize_path("res://scripts/update_and_restart.sh")
	
	# Using 'sh' explicitly to avoid issues with execute permissions or shebangs
	var args = [script_path]
	var pid = OS.create_process("sh", args) # On Linux server, this will be /bin/sh or similar

	if pid == -1:
		printerr("[AdminManager] Failed to launch update_and_restart.sh script.")
		return {"status": "error", "message": "Failed to launch update script"}
	else:
		print("[AdminManager] Update script launched successfully (PID: %d). Server will restart soon." % pid)
		# Acknowledge the request immediately, server will restart after this response is sent
		return {"status": "success", "message": "Update script launched, server restarting."}

func _exit_tree():
	if http_server:
		http_server.server.stop()
		print("[AdminManager] Admin HTTP Server stopped.")

func initialize(server_world_instance: Node):
	# You can pass a reference to server_world if needed for other manager interactions
	pass

