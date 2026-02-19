extends Node

## Logging utility for CubeVi Swizzle

const PREFIX := "[CubeVi_Swizzle]"

enum LogLevel {
	INFO,
	WARNING,
	ERROR,
	IMPORTANT
}

const LEVEL_COLORS := {
	LogLevel.INFO: Color.GRAY,
	LogLevel.WARNING: Color.ORANGE,
	LogLevel.ERROR: Color.MAGENTA,
	LogLevel.IMPORTANT: Color.CYAN
}

const LEVEL_NAMES := {
	LogLevel.INFO: "Info",
	LogLevel.WARNING: "Warning",
	LogLevel.ERROR: "Error",
	LogLevel.IMPORTANT: "Important"
}


func _ready():
	# Ensure this node persists across scene changes
	process_mode = Node.PROCESS_MODE_ALWAYS


func _log_message(message: String, level: LogLevel) -> void:
	var color := LEVEL_COLORS.get(level, Color.WHITE) as Color
	var level_name := LEVEL_NAMES.get(level, "Unknown") as String
	
	var formatted_message := "%s [%s]: %s" % [PREFIX, level_name, message]
	var colored_message := "[color=#%s]%s[/color]" % [color.to_html(), formatted_message]
	
	match level:
		LogLevel.INFO, LogLevel.IMPORTANT:
			print_rich(colored_message)
		LogLevel.WARNING:
			push_warning(formatted_message)
			print_rich(colored_message)
		LogLevel.ERROR:
			push_error(formatted_message)
			print_rich(colored_message)


func log_info(message: String) -> void:
	_log_message(message, LogLevel.INFO)


func log_warning(message: String) -> void:
	_log_message(message, LogLevel.WARNING)


func log_error(message: String) -> void:
	_log_message(message, LogLevel.ERROR)


func log_important(message: String) -> void:
	_log_message(message, LogLevel.IMPORTANT)
