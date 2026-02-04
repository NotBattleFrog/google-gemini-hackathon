extends Node

# Asymmetric Tracking
@export var west_pollution: float = 0.0
@export var east_corruption: float = 0.0

# Configuration
const BASE_SPAWN_INTERVAL: float = 5.0

# Spawn Timers
var timer_west: Timer
var timer_east: Timer

# Signals
signal wave_unit_spawned(unit_type: String, location: Vector2)

func _ready() -> void:
	_setup_timers()
	start_waves()

func _setup_timers() -> void:
	timer_west = Timer.new()
	timer_west.one_shot = false
	timer_west.timeout.connect(_spawn_west_wave)
	add_child(timer_west)
	
	timer_east = Timer.new()
	timer_east.one_shot = false
	timer_east.timeout.connect(_spawn_east_wave)
	add_child(timer_east)

func start_waves() -> void:
	# Initial Start
	# timer_west.start(BASE_SPAWN_INTERVAL)
	# timer_east.start(BASE_SPAWN_INTERVAL)
	print("WaveManager: Spawning disabled for Living Garrison testing.")

func _spawn_west_wave() -> void:
	# Empire of Steel logic
	# Pollution makes waves faster and stronger
	var difficulty_mod = 1.0 + (west_pollution * 0.1)
	var interval = max(1.0, BASE_SPAWN_INTERVAL / difficulty_mod)
	timer_west.start(interval)
	
	# Decisions: Tank or Musketeer?
	var unit_type = "SiegeTank" if west_pollution > 5.0 and randf() > 0.7 else "Musketeer"
	_spawn_unit(unit_type, Vector2(-600, 0), "WEST") # West spawns on left

func _spawn_east_wave() -> void:
	# Dynasty of Roots logic
	# Corruption makes waves faster and swarmer
	var difficulty_mod = 1.0 + (east_corruption * 0.1)
	var interval = max(1.0, BASE_SPAWN_INTERVAL / difficulty_mod)
	timer_east.start(interval)
	
	# Decisions: Ent or SpiritFox?
	var unit_type = "Ent" if east_corruption > 5.0 and randf() > 0.7 else "SpiritFox"
	_spawn_unit(unit_type, Vector2(600, 0), "EAST") # East spawns on right

func _spawn_unit(type: String, pos: Vector2, faction: String) -> void:
	# In real impl, instantiate scene. For now, signal to Main Game to do it.
	print("WaveManager: Spawning %s for %s (Pollution: %.1f, Corruption: %.1f)" % [type, faction, west_pollution, east_corruption])
	emit_signal("wave_unit_spawned", type, pos)
