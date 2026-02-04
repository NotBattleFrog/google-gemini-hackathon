extends Control

@onready var chronicle_label = $VBoxContainer/ChronicleScroll/ChronicleLabel
@onready var restart_button = $VBoxContainer/RestartButton

func _ready() -> void:
    _display_chronicle()

func _display_chronicle() -> void:
    var lore = LoreManager.chronicle_log
    
    var text = "[center][b]THE REIGN OF KING THEODEN HAS ENDED[/b][/center]\n\n"
    text += "[i]The Annals of History:[/i]\n"
    
    if lore.is_empty():
        text += "History has forgotten this reign..."
    else:
        for entry in lore:
            text += "- " + entry + "\n"
            
    chronicle_label.text = text

func _on_restart_button_pressed() -> void:
    # Reset Game State (Simplification)
    SaveManager.current_state["castle_hp"] = 100
    SaveManager.current_state["wave_number"] = 1
    SaveManager.current_state["gold"] = 50
    LoreManager.chronicle_log.clear() # Clear lore for new run? Or keep persistence?
    # Roguelite often keeps it. Let's keep it for "Legacy" feel, or clear if it's "This Run"
    # User spec said "Summarizing the reign", implies just this run usually, but LoreManager is "Legacy".
    # Let's keep it but maybe add a separator?
    LoreManager.add_event("--- NEW REIGN BEGAN ---")
    
    get_tree().change_scene_to_file("res://Scenes/Game.tscn")

func _on_main_menu_button_pressed() -> void:
    get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
