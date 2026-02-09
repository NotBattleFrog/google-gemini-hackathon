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

func _on_main_menu_button_pressed() -> void:
    get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
