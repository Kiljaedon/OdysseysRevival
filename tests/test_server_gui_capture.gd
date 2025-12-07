extends SceneTree

func _init():
	print("Starting Server GUI Capture Test...")
	
	# 1. Setup Temp Log
	var log_path = "user://test_capture.log"
	var file = FileAccess.open(log_path, FileAccess.WRITE)
	if not file:
		print("FAIL: Could not write temp file")
		quit(1)
		
	file.store_line("Old Log Line 1")
	file.store_line("Old Log Line 2")
	file.store_line("=== ODYSSEYS REVIVAL - DEVELOPMENT SERVER ===")
	file.store_line("[SERVER] Startup success")
	file.store_line("[INFO] Waiting for players...")
	file.close()
	
	# 2. Instantiate UI Manager
	var UIManager = load("res://source/server/managers/ui_manager.gd")
	var ui = UIManager.new()
	var dummy_server = Node2D.new()
	
	# 3. Initialize with custom path
	ui.initialize(dummy_server, log_path)
	
	# 4. Run process simulation
	# _setup calls _scan_buffer_for_marker immediately.
	
	print("Checking initial capture...")
	# Check if marker was found
	if not ui._session_marker_found:
		print("FAIL: Marker not found in initial scan!")
		print("Buffer content: ", ui._log_buffer)
		quit(1)
		
	# Check filtering
	if ui._log_buffer.find("Old Log Line 1") != -1:
		print("FAIL: Found old logs in buffer!")
		print("Buffer content: ", ui._log_buffer)
		quit(1)
		
	if ui._log_buffer.find("[SERVER] Startup success") == -1:
		print("FAIL: Missing startup log in buffer!")
		print("Buffer content: ", ui._log_buffer)
		quit(1)

	# 5. Test Append logic
	print("Testing live append...")
	file = FileAccess.open(log_path, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_line("[PLAYER] New Player joined")
	file.close()
	
	# Force process update with retries
	var found_append = false
	for i in range(10):
		ui._process(0.2)
		if ui._log_buffer.find("[PLAYER] New Player joined") != -1:
			found_append = true
			break
		OS.delay_msec(100)
	
	if not found_append:
		print("FAIL: New log line not captured!")
		print("Buffer content: ", ui._log_buffer)
		quit(1)
		return

	print("PASS: All capture checks passed.")
	
	# Cleanup
	# ui.queue_free() # Can't queue free in SceneTree script easily without leak
	
	# Clean file
	# Convert user:// to absolute for cleanup
	var abs_path = ProjectSettings.globalize_path(log_path)
	DirAccess.remove_absolute(abs_path)
	
	quit(0)
