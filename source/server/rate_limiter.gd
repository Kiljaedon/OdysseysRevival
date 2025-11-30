extends Node
class_name RateLimiter

## RPC Rate Limiting System
## Prevents abuse by tracking call frequency per peer across different RPC types

# Track RPC calls per peer: {peer_id: {rpc_name: {calls: Array[float], last_call: float}}}
var rpc_history: Dictionary = {}

# Rate limit configurations (can be adjusted per RPC type)
var rate_limits: Dictionary = {
	"combat_action": {"max_calls": 2, "time_window": 1.0},  # 2 actions per second
	"chat_message": {"max_calls": 5, "time_window": 10.0},  # 5 messages per 10 seconds
	"character_management": {"max_calls": 1, "time_window": 2.0},  # 1 action per 2 seconds
}


func _ready():
	print("[RateLimiter] Initialized - tracking RPC call frequencies")


## Check if peer is allowed to make this RPC call
func check_rate_limit(peer_id: int, rpc_name: String, max_calls: int, time_window: float) -> Dictionary:
	## Returns: {allowed: bool, wait_time: float, calls_in_window: int}
	var current_time = Time.get_ticks_msec() / 1000.0

	# Initialize peer tracking if first call
	if not rpc_history.has(peer_id):
		rpc_history[peer_id] = {}

	# Initialize RPC tracking if first call of this type
	if not rpc_history[peer_id].has(rpc_name):
		rpc_history[peer_id][rpc_name] = {
			"calls": [],
			"last_call": 0
		}

	var rpc_data = rpc_history[peer_id][rpc_name]

	# Clean old calls outside time window
	var cutoff_time = current_time - time_window
	var filtered_calls = []
	for call_time in rpc_data.calls:
		if call_time > cutoff_time:
			filtered_calls.append(call_time)
	rpc_data.calls = filtered_calls

	# Check if limit exceeded
	if rpc_data.calls.size() >= max_calls:
		var oldest_call = rpc_data.calls[0]
		var wait_time = (oldest_call + time_window) - current_time

		return {
			"allowed": false,
			"wait_time": wait_time,
			"calls_in_window": rpc_data.calls.size()
		}

	# Record this call
	rpc_data.calls.append(current_time)
	rpc_data.last_call = current_time

	return {
		"allowed": true,
		"wait_time": 0,
		"calls_in_window": rpc_data.calls.size() + 1
	}


## Cleanup tracking for disconnected peer
func cleanup_peer(peer_id: int):
	## Remove all RPC history for this peer when they disconnect
	if rpc_history.has(peer_id):
		rpc_history.erase(peer_id)
		print("[RateLimiter] Cleaned up history for peer %d" % peer_id)


## Get rate limit config for RPC type (with defaults)
func get_limit_config(rpc_type: String) -> Dictionary:
	## Returns {max_calls: int, time_window: float} for this RPC type
	if rate_limits.has(rpc_type):
		return rate_limits[rpc_type]
	else:
		# Default fallback: 10 calls per 5 seconds
		return {"max_calls": 10, "time_window": 5.0}


## Helper: Get stats for monitoring/debugging
func get_peer_stats(peer_id: int) -> Dictionary:
	## Returns RPC call statistics for this peer
	if not rpc_history.has(peer_id):
		return {"tracked_rpcs": 0, "total_calls": 0}

	var peer_data = rpc_history[peer_id]
	var total_calls = 0

	for rpc_name in peer_data:
		total_calls += peer_data[rpc_name].calls.size()

	return {
		"tracked_rpcs": peer_data.keys().size(),
		"total_calls": total_calls,
		"rpc_breakdown": peer_data
	}
