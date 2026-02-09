extends Node

var api_key: String = ""
var config_path: String = "user://settings.cfg"
var config_file: ConfigFile = ConfigFile.new()

func _ready() -> void:
    load_config()

func save_api_key(key: String) -> void:
    api_key = key
    config_file.set_value("auth", "api_key", api_key)
    var err = config_file.save(config_path)
    if err != OK:
        push_error("Failed to save config: %s" % err)
    else:
        print("API Key saved successfully.")
        # Log API key (masked for security)
        var masked_key = api_key.substr(0, 10) + "..." + api_key.substr(api_key.length() - 4)
        print("[ConfigManager] Saved API Key: %s (length: %d)" % [masked_key, api_key.length()])
        print("[ConfigManager] Full API Key (for debugging): %s" % api_key)

func load_config() -> void:
    # CODE DEFAULT TAKES PRIORITY - Use this value from code
    var code_default_key = "AIzaSyCWgSRFKv_vEZSFZkbawDmYlHgaNwaR5Io"
    
    # Try to load from file first
    var file_key = ""
    var err = config_file.load(config_path)
    if err == OK:
        file_key = config_file.get_value("auth", "api_key", "")
        print("[ConfigManager] Loaded from file - API Key length: %d" % file_key.length())
        if file_key.length() > 0:
            print("[ConfigManager] First 10 chars from file: %s" % file_key.substr(0, min(10, file_key.length())))
    else:
        print("[ConfigManager] No config file found or failed to load.")
    
    # PRIORITY: Use code default if it's set (overrides saved file)
    if code_default_key.length() >= 20:
        api_key = code_default_key
        print("[ConfigManager] Using CODE DEFAULT API key (overrides saved file)")
        print("[ConfigManager] Code default key: %s" % code_default_key.substr(0, 10) + "...")
        # Save the code default to file so it persists
        save_api_key(api_key)
    # Fallback: Use file key if code default is not set
    elif file_key.length() >= 20:
        api_key = file_key
        print("[ConfigManager] Using API key from saved file")
    # Last resort: Use code default even if empty (shouldn't happen)
    else:
        api_key = code_default_key
        print("[ConfigManager] No valid key found, using code default")
        if api_key.length() >= 20:
            save_api_key(api_key)
    
    # Log API key (masked for security)
    if not api_key.is_empty():
        var masked_key = api_key.substr(0, 10) + "..." + api_key.substr(api_key.length() - 4)
        print("[ConfigManager] API Key loaded: %s (length: %d)" % [masked_key, api_key.length()])
        print("[ConfigManager] Full API Key (for debugging): %s" % api_key)
    else:
        print("[ConfigManager] WARNING: API Key is empty!")
