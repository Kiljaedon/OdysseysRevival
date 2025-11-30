extends Node
class_name AuthManager

## Server-side authentication and permission manager

var authenticated_peers: Dictionary = {}

func authenticate_peer(peer_id: int, username: String, admin_level: int) -> void:
	authenticated_peers[peer_id] = {"username": username, "admin_level": admin_level}
	print("[AuthManager] Authenticated peer %d as '%s' (admin_level: %d)" % [peer_id, username, admin_level])

func is_authenticated(peer_id: int) -> bool:
	return authenticated_peers.has(peer_id)

func get_admin_level(peer_id: int) -> int:
	return authenticated_peers.get(peer_id, {}).get("admin_level", 0)

func is_admin(peer_id: int) -> bool:
	return get_admin_level(peer_id) >= 1

func is_superadmin(peer_id: int) -> bool:
	return get_admin_level(peer_id) >= 2

func get_username(peer_id: int) -> String:
	return authenticated_peers.get(peer_id, {}).get("username", "")

func remove_peer(peer_id: int) -> void:
	if authenticated_peers.has(peer_id):
		print("[AuthManager] Removed peer %d (%s)" % [peer_id, get_username(peer_id)])
		authenticated_peers.erase(peer_id)

func require_admin(peer_id: int) -> bool:
	if not is_admin(peer_id):
		print("[AuthManager] DENIED: Peer %d attempted admin action without permission" % peer_id)
		return false
	return true
