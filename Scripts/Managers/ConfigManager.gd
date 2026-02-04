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

func load_config() -> void:
    var err = config_file.load(config_path)
    if err == OK:
        api_key = config_file.get_value("auth", "api_key", "")
        print("Config loaded. API Key present: %s" % (not api_key.is_empty()))
    else:
        print("No config file found or failed to load. Defaulting to empty.")
