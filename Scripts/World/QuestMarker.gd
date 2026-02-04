extends Sprite2D

# Quest marker that appears in the world

var quest: Quest

func _ready() -> void:
	# Pulsing animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.5)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)

func set_quest(new_quest: Quest) -> void:
	quest = new_quest
	
	# Change color based on urgency
	match quest.urgency:
		"CRITICAL":
			modulate = Color.RED
		"HIGH":
			modulate = Color.ORANGE
		"MEDIUM":
			modulate = Color.YELLOW
		"LOW":
			modulate = Color.WHITE
