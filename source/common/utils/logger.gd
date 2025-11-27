class_name Logger
extends RefCounted
## Logger - Centralized logging with toggleable levels
## Use this instead of print() for production-ready logging

enum Level {
	DEBUG = 0,   # Verbose debugging info (disabled in release)
	INFO = 1,    # General information
	WARN = 2,    # Warnings that don't stop execution
	ERROR = 3,   # Errors that may affect functionality
	NONE = 4     # Disable all logging
}

# Global log level - set higher to reduce spam
# DEBUG in dev, INFO or WARN in production
static var log_level: Level = Level.DEBUG

# Category-specific overrides (e.g., {"Network": Level.WARN} to silence network spam)
static var category_levels: Dictionary = {}

# Enable/disable timestamp prefix
static var show_timestamps: bool = false

# Enable/disable category prefix
static var show_category: bool = true


static func set_release_mode():
	"""Configure for production - minimal logging"""
	log_level = Level.WARN
	show_timestamps = false


static func set_debug_mode():
	"""Configure for development - verbose logging"""
	log_level = Level.DEBUG
	show_timestamps = true


static func silence_category(category: String):
	"""Silence a specific category (useful for spammy systems)"""
	category_levels[category] = Level.NONE


static func set_category_level(category: String, level: Level):
	"""Set log level for a specific category"""
	category_levels[category] = level


static func _should_log(level: Level, category: String) -> bool:
	"""Check if message should be logged based on level and category"""
	# Check category-specific override first
	if category_levels.has(category):
		return level >= category_levels[category]
	# Fall back to global level
	return level >= log_level


static func _format_message(level: Level, category: String, message: String) -> String:
	"""Format log message with optional prefix"""
	var parts = []

	if show_timestamps:
		var time = Time.get_time_dict_from_system()
		parts.append("[%02d:%02d:%02d]" % [time.hour, time.minute, time.second])

	# Level prefix
	match level:
		Level.DEBUG: parts.append("[DEBUG]")
		Level.INFO: parts.append("[INFO]")
		Level.WARN: parts.append("[WARN]")
		Level.ERROR: parts.append("[ERROR]")

	if show_category and category != "":
		parts.append("[%s]" % category)

	parts.append(message)
	return " ".join(parts)


# ========== LOGGING METHODS ==========

static func debug(message: String, category: String = ""):
	"""Log debug message - verbose, disabled in release"""
	if _should_log(Level.DEBUG, category):
		print(_format_message(Level.DEBUG, category, message))


static func info(message: String, category: String = ""):
	"""Log info message - general information"""
	if _should_log(Level.INFO, category):
		print(_format_message(Level.INFO, category, message))


static func warn(message: String, category: String = ""):
	"""Log warning message"""
	if _should_log(Level.WARN, category):
		push_warning(_format_message(Level.WARN, category, message))


static func error(message: String, category: String = ""):
	"""Log error message"""
	if _should_log(Level.ERROR, category):
		push_error(_format_message(Level.ERROR, category, message))


# ========== CONVENIENCE SHORTCUTS ==========
# For common categories to avoid typos

static func network(message: String, level: Level = Level.DEBUG):
	"""Log network-related message"""
	match level:
		Level.DEBUG: debug(message, "Network")
		Level.INFO: info(message, "Network")
		Level.WARN: warn(message, "Network")
		Level.ERROR: error(message, "Network")


static func battle(message: String, level: Level = Level.DEBUG):
	"""Log battle-related message"""
	match level:
		Level.DEBUG: debug(message, "Battle")
		Level.INFO: info(message, "Battle")
		Level.WARN: warn(message, "Battle")
		Level.ERROR: error(message, "Battle")


static func auth(message: String, level: Level = Level.DEBUG):
	"""Log authentication-related message"""
	match level:
		Level.DEBUG: debug(message, "Auth")
		Level.INFO: info(message, "Auth")
		Level.WARN: warn(message, "Auth")
		Level.ERROR: error(message, "Auth")


static func ui(message: String, level: Level = Level.DEBUG):
	"""Log UI-related message"""
	match level:
		Level.DEBUG: debug(message, "UI")
		Level.INFO: info(message, "UI")
		Level.WARN: warn(message, "UI")
		Level.ERROR: error(message, "UI")
