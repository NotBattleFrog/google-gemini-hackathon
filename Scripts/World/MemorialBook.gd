extends Area2D

var chronicle: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Load a random previous chronicle
	var chronicles = LoreManager.load_chronicles()
	if not chronicles.is_empty():
		chronicle = chronicles.pick_random()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not chronicle.is_empty():
		show_chronicle_popup()

func show_chronicle_popup() -> void:
	# Simple popup (can be enhanced with a proper Panel later)
	print("=== MEMORIAL BOOK ===")
	print("Title: %s" % chronicle.get("ruler_title", "Unknown"))
	print("\n%s" % chronicle.get("narrative", "No story found."))
	print("====================")
	
	# TODO: Show actual UI panel instead of console
