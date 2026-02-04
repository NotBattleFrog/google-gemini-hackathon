extends Node2D

@onready var light = $PointLight2D

func _ready() -> void:
	z_index = -1 # Draw behind units
	# Connect to Global Signals for Day/Night cycle
	GlobalSignalBus.night_started.connect(_on_night)
	GlobalSignalBus.day_started.connect(_on_day)
	
	# Initial state check
	light.energy = 0.0

func _on_night() -> void:
	# print("Lamp: Night detected. Turning ON.")
	var tween = create_tween()
	tween.tween_property(light, "energy", 1.5, 2.0)

func _on_day() -> void:
	# print("Lamp: Day detected. Turning OFF.")
	var tween = create_tween()
	tween.tween_property(light, "energy", 0.0, 2.0)
