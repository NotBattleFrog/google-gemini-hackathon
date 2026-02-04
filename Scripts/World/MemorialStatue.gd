extends Node2D

var chronicle: Dictionary = {}

func _ready() -> void:
	# Load the latest chronicle
	chronicle = LoreManager.get_latest_chronicle()
	
	if not chronicle.is_empty():
		update_display()

func update_display() -> void:
	var label = find_child("Nameplate", false, false)
	if label:
		var title = chronicle.get("ruler_title", "The Forgotten")
		label.text = "Here lies\n%s" % title
