extends Node
## Minimal connection test - bypasses BaseClient/BaseServer

func _ready():
	print("=== MINIMAL CONNECTION TEST ===")
	
	# Create WebSocket peer
	var peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_client("ws://127.0.0.1:8043")
	
	if error != OK:
		print("ERROR creating client: ", error)
		return
	
	# Set as multiplayer peer
	multiplayer.multiplayer_peer = peer
	
	# Connect signals
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)
	
	print("Attempting connection...")


func _on_connected():
	print("✅ CONNECTED! Peer ID: ", multiplayer.get_unique_id())
	print("Staying connected...")


func _on_failed():
	print("❌ CONNECTION FAILED")


func _on_disconnected():
	print("⚠️ SERVER DISCONNECTED")
