extends Node

const SAVE_PATH: String = "user://savegame.json"

var current_state: Dictionary = {
    "gold": 0,
    "wave_number": 1,
    "castle_hp": 100,
    "difficulty_level": 1 # 0=Easy, 1=Normal, 2=Hard
}

func _ready() -> void:
    # Optional: Automatically load on start, or wait for MainMenu
    pass

func save_game() -> void:
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        var json_string = JSON.stringify(current_state)
        file.store_string(json_string)
        file.close()
        print("Game saved successfully.")
    else:
        push_error("Failed to save game at %s" % SAVE_PATH)

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        print("No save file found.")
        return false
    
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file:
        push_error("Failed to open save file.")
        return false
    
    var content = file.get_as_text()
    var json = JSON.new()
    var error = json.parse(content)
    
    if error == OK:
        var data = json.data
        if data is Dictionary:
            # Safely merge to avoid missing keys if schema changes
            for key in current_state.keys():
                if data.has(key):
                    current_state[key] = data[key]
            
            # Broadcast updates (optional, or rely on getters)
            GlobalSignalBus.gold_changed.emit(current_state["gold"])
            print("Game loaded successfully.")
            return true
    else:
        push_error("JSON Parse Error: %s in %s at line %s" % [json.get_error_message(), content, json.get_error_line()])
        
    return false
