class_name ConfigManager
extends Node
## Manages server and client configuration files
## Provides IP auto-detection and connection info management

const SERVER_CONFIG_PATH = "res://data/server_config.json"
const CLIENT_CONFIG_PATH = "res://data/client_config.json"

## Server environment presets
enum ServerEnvironment { LOCAL, REMOTE }

const SERVER_ENVIRONMENTS = {
	ServerEnvironment.LOCAL: {
		"name": "Local (Development)",
		"address": "127.0.0.1",
		"port": 9043
	},
	ServerEnvironment.REMOTE: {
		"name": "Remote (Odyssey)",
		"address": "178.156.202.89",
		"port": 9043
	}
}

## Get the current server environment from config
static func get_server_environment() -> int:
	var config = get_client_config()
	return config.get("server_environment", ServerEnvironment.LOCAL)

## Set the server environment and update config
static func set_server_environment(env: int) -> void:
	var env_config = SERVER_ENVIRONMENTS.get(env, SERVER_ENVIRONMENTS[ServerEnvironment.LOCAL])
	var config = get_client_config()
	config["server_environment"] = env
	config["server_address"] = env_config.address
	config["server_port"] = env_config.port
	save_client_config(config)
	print("[ConfigManager] Switched to %s server: %s:%d" % [env_config.name, env_config.address, env_config.port])

## Get environment name for display
static func get_environment_name(env: int) -> String:
	return SERVER_ENVIRONMENTS.get(env, SERVER_ENVIRONMENTS[ServerEnvironment.LOCAL]).name

## Get server configuration
static func get_server_config() -> Dictionary:
	var default_config = {
		"port": 9043,
		"tick_rate": 0.05,
		"max_players": 100,
		"server_name": "Odysseys Revival - Development Server"
	}

	var config_file = ProjectSettings.globalize_path(SERVER_CONFIG_PATH)

	if not FileAccess.file_exists(config_file):
		# Create default config
		save_server_config(default_config)
		return default_config

	var file = FileAccess.open(config_file, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_text) == OK:
			return json.data

	return default_config


## Save server configuration
static func save_server_config(config: Dictionary) -> bool:
	var config_file = ProjectSettings.globalize_path(SERVER_CONFIG_PATH)

	var file = FileAccess.open(config_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()
		return true
	return false


## Get client configuration
static func get_client_config() -> Dictionary:
	var default_address = "127.0.0.1"
	var default_env = ServerEnvironment.LOCAL
	
	# Production build override - Force remote server
	if OS.has_feature("production"):
		default_address = "178.156.202.89"
		default_env = ServerEnvironment.REMOTE
		print("[ConfigManager] Production build detected - defaulting to Remote Server")

	var default_config = {
		"server_address": default_address,
		"server_port": 9043,
		"server_environment": default_env,
		"last_updated": Time.get_datetime_string_from_system()
	}

	var config_file = ProjectSettings.globalize_path(CLIENT_CONFIG_PATH)

	if not FileAccess.file_exists(config_file):
		# Create default config
		save_client_config(default_config)
		return default_config

	var file = FileAccess.open(config_file, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		if json.parse(json_text) == OK:
			var data = json.data
			# If production build, FORCE the address even if config file exists (unless dev override)
			if OS.has_feature("production") and not OS.has_feature("allow_local_config"):
				data["server_address"] = "178.156.202.89"
				data["server_environment"] = ServerEnvironment.REMOTE
			return data

	return default_config


## Save client configuration
static func save_client_config(config: Dictionary) -> bool:
	var config_file = ProjectSettings.globalize_path(CLIENT_CONFIG_PATH)

	# Add timestamp
	config["last_updated"] = Time.get_datetime_string_from_system()

	var file = FileAccess.open(config_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()
		return true
	return false


## Detect local IP address
static func get_local_ip() -> String:
	var local_addresses = IP.get_local_addresses()

	# Filter out localhost and find the most likely LAN IP
	for address in local_addresses:
		# Skip localhost
		if address == "127.0.0.1" or address == "::1":
			continue

		# Prefer IPv4 addresses starting with 192.168 or 10.0
		if address.begins_with("192.168.") or address.begins_with("10.0."):
			return address

		# Fallback to any IPv4 address
		if "." in address and not ":" in address:
			return address

	# Fallback to localhost
	return "127.0.0.1"


## Get public IP (requires internet connection)
static func get_public_ip_async(callback: Callable):
	"""Get public IP address asynchronously using HTTP request"""
	var http = HTTPRequest.new()

	# Use a lambda to handle the response
	http.request_completed.connect(func(result, response_code, headers, body):
		var public_ip = "Unknown"
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
			public_ip = body.get_string_from_utf8().strip_edges()
		callback.call(public_ip)
		http.queue_free()
	)

	# Add to scene tree temporarily
	var tree = Engine.get_main_loop()
	if tree:
		tree.root.add_child(http)
		http.request("https://api.ipify.org")


## Generate connection info for copy-paste
static func generate_connection_info(local_ip: String, public_ip: String, port: int) -> String:
	var info = ""
	info += "========== SERVER CONNECTION INFO ==========\n"
	info += "Server Name: Odysseys Revival\n"
	info += "Port: %d\n\n" % port
	info += "LOCAL NETWORK (Same WiFi/LAN):\n"
	info += "  Address: %s\n\n" % local_ip
	info += "INTERNET (Remote Players):\n"
	info += "  Address: %s\n" % public_ip
	info += "  NOTE: Port forwarding required!\n\n"
	info += "CLIENT CONFIG (Copy to client_config.json):\n"
	info += "{\n"
	info += "\t\"server_address\": \"%s\",\n" % local_ip
	info += "\t\"server_port\": %d\n" % port
	info += "}\n"
	info += "==========================================="
	return info


## Generate just the JSON config for easy copy-paste
static func generate_client_config_json(address: String, port: int) -> String:
	var config = {
		"server_address": address,
		"server_port": port,
		"last_updated": Time.get_datetime_string_from_system()
	}
	return JSON.stringify(config, "\t")


## Check if currently configured to connect to local server
static func is_local_server() -> bool:
	var env = get_server_environment()
	return env == ServerEnvironment.LOCAL


## Check if the current server address is localhost
static func is_localhost() -> bool:
	var config = get_client_config()
	var address = config.get("server_address", "")
	return address == "127.0.0.1" or address == "localhost"
