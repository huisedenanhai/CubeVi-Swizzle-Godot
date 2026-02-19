extends Node

## Device configuration loader with AES decryption
## Loads calibration data from OpenStageAI config file

const PASSPHRASE := "3f5e1a2b4c6d7e8f9a0b1c2d3e4f5a6b"
const ITERATIONS := 1

var device_defaults = preload("res://autoload/device_defaults.gd")

## Device parameters (loaded from config or use defaults)
var device_params: Dictionary = device_defaults.get_defaults()


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_device_config()


func load_device_config() -> void:
	var config_path := _get_config_path()
	
	if not FileAccess.file_exists(config_path):
		SwizzleLogger.log_warning("Config file not found at: %s, using default parameters" % config_path)
		return
	
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		SwizzleLogger.log_error("Failed to open config file: %s" % config_path)
		return
	
	var json_content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_content)
	
	if error != OK:
		SwizzleLogger.log_error("Failed to parse config JSON")
		return
	
	var data := json.data as Dictionary
	if not data.has("config"):
		SwizzleLogger.log_error("Config field not found in JSON")
		return
	
	var encrypted_config := data["config"] as String
	var decrypted := _decrypt_aes(encrypted_config)
	
	if decrypted.is_empty():
		SwizzleLogger.log_error("Failed to decrypt config")
		return
	
	# Parse decrypted config
	var config_json := JSON.new()
	error = config_json.parse(decrypted)
	
	if error != OK:
		SwizzleLogger.log_error("Failed to parse decrypted config")
		return
	
	var config_data := config_json.data as Dictionary
	if config_data.has("config"):
		var inner_config := config_data["config"] as Dictionary
		if inner_config.has("obliquity"):
			device_params["slope"] = inner_config["obliquity"]
		if inner_config.has("lineNumber"):
			device_params["interval"] = inner_config["lineNumber"]
		if inner_config.has("deviation"):
			device_params["x0"] = inner_config["deviation"]
	
	SwizzleLogger.log_important("Loaded device calibration from config file")


func _get_config_path() -> String:
	# OpenStageAI config location - platform specific
	var config_dir := ""
	match OS.get_name():
		"Windows":
			config_dir = OS.get_environment("APPDATA")
		"macOS":
			config_dir = OS.get_environment("HOME") + "/Library/Application Support"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			config_dir = OS.get_environment("HOME") + "/.config"
		_:
			config_dir = OS.get_user_data_dir()
	
	return config_dir.path_join("OpenstageAI").path_join("deviceConfig.json")


func _decrypt_aes(encrypted_string: String) -> String:
	# Base64 decode
	var base64_bytes := Marshalls.base64_to_raw(encrypted_string)
	if base64_bytes.size() < 16:
		return ""
	
	# Extract salt (bytes 8-16) and ciphertext (bytes 16+)
	var salt := base64_bytes.slice(8, 16)
	var cipher_text := base64_bytes.slice(16)
	
	# Derive key and IV using MD5
	var passphrase_bytes := PASSPHRASE.to_utf8_buffer()
	var key_iv := _derive_key_iv(passphrase_bytes, salt)
	
	if key_iv.is_empty():
		return ""
	
	# Decrypt using AES CBC
	var aes := AESContext.new()
	var error := aes.start(AESContext.MODE_CBC_DECRYPT, key_iv["key"], key_iv["iv"])
	
	if error != OK:
		return ""
	
	var decrypted := aes.update(cipher_text)
	aes.finish()
	
	return decrypted.get_string_from_utf8()


func _derive_key_iv(passphrase: PackedByteArray, salt: PackedByteArray) -> Dictionary:
	var hash_list: Array[PackedByteArray] = []
	
	# First hash
	var pre_hash := passphrase.duplicate()
	pre_hash.append_array(salt)
	
	var md5 := HashingContext.new()
	md5.start(HashingContext.HASH_MD5)
	md5.update(pre_hash)
	var current_hash := md5.finish()
	
	# Apply iterations
	for i in range(ITERATIONS - 1):
		md5.start(HashingContext.HASH_MD5)
		md5.update(current_hash)
		current_hash = md5.finish()
	
	hash_list.append(current_hash)
	
	# Generate enough bytes for 32-byte key + 16-byte IV
	while _total_bytes(hash_list) < 48:
		var new_pre := current_hash.duplicate()
		new_pre.append_array(passphrase)
		new_pre.append_array(salt)
		
		md5.start(HashingContext.HASH_MD5)
		md5.update(new_pre)
		current_hash = md5.finish()
		
		for i in range(ITERATIONS - 1):
			md5.start(HashingContext.HASH_MD5)
			md5.update(current_hash)
			current_hash = md5.finish()
		
		hash_list.append(current_hash)
	
	# Concatenate all hashes
	var full_hash := PackedByteArray()
	for h in hash_list:
		full_hash.append_array(h)
	
	# Extract key (32 bytes) and IV (16 bytes)
	return {
		"key": full_hash.slice(0, 32),
		"iv": full_hash.slice(32, 48)
	}


func _total_bytes(arrays: Array[PackedByteArray]) -> int:
	var total := 0
	for a in arrays:
		total += a.size()
	return total


## Get device parameter value
func get_param(key: String) -> Variant:
	return device_params.get(key)


## Get all device parameters
func get_all_params() -> Dictionary:
	return device_params.duplicate()
