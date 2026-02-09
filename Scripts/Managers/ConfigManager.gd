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

func load_config() -> void:
    # Load API key from saved file only - no hardcoded defaults
    var err = config_file.load(config_path)
    if err == OK:
        api_key = config_file.get_value("auth", "api_key", "")
        print("[ConfigManager] Loaded from file - API Key length: %d" % api_key.length())
        if api_key.length() > 0:
            print("[ConfigManager] First 10 chars from file: %s" % api_key.substr(0, min(10, api_key.length())))
        else:
            print("[ConfigManager] No API key found in config file.")
    else:
        print("[ConfigManager] No config file found or failed to load.")
        api_key = ""
    
    # Log API key status (masked for security)
    if not api_key.is_empty():
        var masked_key = api_key.substr(0, 10) + "..." + api_key.substr(api_key.length() - 4)
        print("[ConfigManager] API Key loaded: %s (length: %d)" % [masked_key, api_key.length()])
    else:
        print("[ConfigManager] WARNING: API Key is empty! Please set it via the UI (press K) or config file.")
