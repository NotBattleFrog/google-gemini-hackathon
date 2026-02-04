extends Node2D

@onready var player_spawn = $PlayerSpawn
@onready var enemy_spawner_timer = $EnemySpawnerTimer
@export var general_scene: PackedScene = preload("res://Scenes/EnemyGeneral.tscn")
@export var enemy_scene: PackedScene = preload("res://Scenes/Enemy.tscn")

# Day/Night & Quest System
var current_day: int = 1
var time_of_day: float = 6.0  # 0-24 hours (start at 6 AM)
var day_night_speed: float = 0.05  # Game hours per real second (slower for testing)
var is_preview: bool = false

func _ready() -> void:
	# Check if we are in a menu preview (SubViewport child)
	var parent = get_parent()
	var is_preview = false
	while parent:
		if parent is SubViewport:
			is_preview = true
			break
		parent = parent.get_parent()
	
	if is_preview:
		print("Game running in menu preview mode - skipping initialization")
		return # Don't spawn anything in preview

	# Reset State
	SaveManager.current_state["castle_hp"] = 100
	SaveManager.current_state["wave_number"] = 1
	GlobalSignalBus.game_started.emit()
	
	# Spawn Vagrant (Tutorial) - Disabled for Quota/Social Test
	# var vagrant = preload("res://Scenes/Vagrant.tscn").instantiate()
	# vagrant.position = Vector2(100, 0) # Near player start
	# add_child(vagrant)

	# Spawn Garrison for Social Test (Reduced for Quota)
	_spawn_garrison_unit("Knight", Vector2(50, 0))
	_spawn_garrison_unit("Archer", Vector2(-50, 0))
	# _spawn_garrison_unit("Builder", Vector2(0, 0))
	
	# Spawn Merchant (far away for testing conversation merging)
	_spawn_garrison_unit("Merchant", Vector2(-300, 0))
	
	# Apply Legacy Effects from previous run
	_apply_legacy_effects()
	
	# Test quest system after 5 seconds
	_test_petition_system()
	
	# Connect to WaveManager
	if WaveManager:
		WaveManager.wave_unit_spawned.connect(_on_wave_unit_spawned)

	# Visuals: Add WorldEnvironment for Glow
	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.2
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.environment = environment
	add_child(env)

	# background Elements
	_setup_atmosphere()
  
	# Lamps
	var lamp_scene = preload("res://Scenes/World/Lamp.tscn")
	var lamp_positions = [Vector2(-150, -60), Vector2(150, -60), Vector2(-400, -60), Vector2(400, -60)]
	for pos in lamp_positions:
		var lamp = lamp_scene.instantiate()
		lamp.position = pos
		add_child(lamp)
	
	# Add Journal UI
	var journal_scene = preload("res://Scenes/UI/Journal.tscn")
	var journal = journal_scene.instantiate()
	add_child(journal)
	
	# Add Petition Panel UI
	var petition_scene = preload("res://Scenes/UI/PetitionPanel.tscn")
	var petition_panel = petition_scene.instantiate()
	add_child(petition_panel)

func _setup_atmosphere() -> void:
	# WEST (Fire/Smoke)
	var west_bg = ColorRect.new()
	west_bg.size = Vector2(400, 648)
	west_bg.position = Vector2(-800, -324) # Approximate left side
	var west_mat = ShaderMaterial.new()
	west_mat.shader = preload("res://Shaders/fire.gdshader")
	west_bg.material = west_mat
	add_child(west_bg)
	move_child(west_bg, 0) # Send to back

	var west_smoke = CPUParticles2D.new()
	west_smoke.position = Vector2(-600, 300)
	west_smoke.amount = 20
	west_smoke.direction = Vector2(0, -1)
	west_smoke.spread = 30.0
	west_smoke.gravity = Vector2(0, -98)
	west_smoke.initial_velocity_min = 50.0
	west_smoke.initial_velocity_max = 100.0
	west_smoke.scale_amount_min = 5.0
	west_smoke.scale_amount_max = 10.0
	west_smoke.color = Color(0.2, 0.2, 0.2, 0.5)
	add_child(west_smoke)

	# EAST (Water/Spores)
	var east_bg = ColorRect.new()
	east_bg.size = Vector2(400, 648)
	east_bg.position = Vector2(400, -324) # Approximate right side
	var east_mat = ShaderMaterial.new()
	east_mat.shader = preload("res://Shaders/water.gdshader")
	east_bg.material = east_mat
	add_child(east_bg)
	move_child(east_bg, 0)

	var east_spores = CPUParticles2D.new()
	east_spores.position = Vector2(600, 300)
	east_spores.amount = 30
	east_spores.direction = Vector2(0, -1)
	east_spores.gravity = Vector2(0, -10)
	east_spores.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	east_spores.emission_sphere_radius = 100.0
	east_spores.scale_amount_min = 2.0
	east_spores.scale_amount_max = 4.0
	east_spores.color = Color(0.5, 0.0, 1.0, 0.8) # Purple spores
	add_child(east_spores)

	# Day/Night Cycle
	_setup_day_night()

var day_night_modulate: CanvasModulate
var is_day: bool = true
var time_elapsed: float = 0.0
const DAY_DURATION = 60.0 # Seconds

func _setup_day_night() -> void:
	day_night_modulate = CanvasModulate.new()
	day_night_modulate.color = Color.WHITE # Noon
	add_child(day_night_modulate)

func _test_petition_system() -> void:
	print("[Game] _test_petition_system() called - waiting 5 seconds...")
	await get_tree().create_timer(5.0).timeout
	print("[Game] ===== TESTING PETITION SYSTEM =====")
	print("[Game] GameStateTracker available: ", GameStateTracker != null)
	print("[Game] PetitionManager available: ", PetitionManager != null)
	
	if GameStateTracker:
		GameStateTracker.log_wall_breach("East", 4)
		GameStateTracker.log_resource_shortage("Gold", 25)
		print("[Game] Events logged successfully")
	else:
		print("[Game] ERROR: GameStateTracker not found!")
		
	if PetitionManager:
		print("[Game] Calling generate_daily_petitions()...")
		PetitionManager.generate_daily_petitions()
	else:
		print("[Game] ERROR: PetitionManager not found!")

func _process(delta: float) -> void:
	# Day/Night Cycle DISABLED for Social Testing
	pass
	# time_elapsed += delta
	# var cycle_pos = fmod(time_elapsed, DAY_DURATION) / DAY_DURATION # 0.0 to 1.0
	# GlobalSignalBus.time_changed.emit(cycle_pos)
	# 
	# # Simple Day/Night Gradient
	# # 0.0 - 0.5: Night -> Dawn -> Day
	# # 0.5 - 1.0: Day -> Dusk -> Night
	# 
	# var target_color = Color.WHITE
	# if cycle_pos < 0.2 or cycle_pos > 0.8:
	# 	target_color = Color(0.1, 0.1, 0.3) # Night Blue
	# 	if is_day:
	# 		is_day = false
	# 		_on_night_started()
	# else:
	# 	target_color = Color.WHITE # Day
	# 	if not is_day:
	# 		is_day = true
	# 		_on_day_started()
	# 		
	# # Smooth transition
	# day_night_modulate.color = day_night_modulate.color.lerp(target_color, delta * 0.5)

func _on_night_started() -> void:
	print("Night has fallen...")
	GlobalSignalBus.night_started.emit()

func _on_day_started() -> void:
	print("The sun rises...")
	GlobalSignalBus.day_started.emit()
	
func _on_wave_unit_spawned(type: String, pos: Vector2) -> void:
	# Instantiate based on type (Simplification: using same Enemy scene for now, changing color/stats)
	var unit = enemy_scene.instantiate()
	unit.position = pos
	
	# Customize based on type (In real full version, load different Scenes)
	if type == "SiegeTank":
		unit.modulate = Color(0.3, 0.3, 0.3) # Dark Grey
		unit.speed = 30.0
	elif type == "SpiritFox":
		unit.modulate = Color(0.3, 0.8, 0.5) # Spirit Green
		unit.speed = 80.0
		
	add_child(unit)
	
	# Optional: If we want to keep the General logic for the prototype
	# spawn_general() can be called manually or by WaveManager special events

func _spawn_garrison_unit(archetype: String, pos: Vector2) -> void:
	# Use Enemy.tscn (Unit base) but configure as Friendly
	var unit = enemy_scene.instantiate()
	unit.position = pos
	unit.faction = "FRIENDLY"
	unit.name = archetype
	
	# Customize Visuals (Tint)
	match archetype:
		"Knight": unit.modulate = Color(0.8, 0.8, 1.0) # Steel Blue
		"Archer": unit.modulate = Color(0.6, 0.8, 0.6) # Ranger Green
		"Builder": unit.modulate = Color(0.8, 0.6, 0.4) # Leather Brown
		"Merchant": unit.modulate = Color(1.0, 0.8, 0.5) # Gold/Yellow
		
	add_child(unit)
	
	# Wait for ready, then set archetype in Soul (hacky force update)
	await get_tree().process_frame
	if unit.soul:
		unit.soul.personality.archetype = archetype

# Legacy System Integration
func _apply_legacy_effects() -> void:
	var previous = LoreManager.get_latest_chronicle()
	if previous.is_empty():
		print("[Game] No previous chronicle found. Fresh start.")
		return
	
	print("[Game] Loading legacy from: %s" % previous.get("ruler_title", "Unknown"))
	
	# Reputation carryover (20% of previous run)
	var east_rep = previous.get("final_reputation", {}).get("east", 0.0)
	var west_rep = previous.get("final_reputation", {}).get("west", 0.0)
	
	var east_mod = east_rep * 0.2
	var west_mod = west_rep * 0.2
	
	print("[Game] Legacy modifiers: East %.2f, West %.2f" % [east_mod, west_mod])
	
	# Apply to WaveManager (increase hostility if negative reputation)
	if WaveManager:
		# Note: This assumes WaveManager has these properties
		# You may need to add them to WaveManager.gd
		# WaveManager.east_hostility_bonus = -east_mod  # Negative reputation = more hostility
		# WaveManager.west_hostility_bonus = -west_mod
		pass
	
	# Spawn memorial
	_spawn_memorial(previous)

func _spawn_memorial(chronicle: Dictionary) -> void:
	var east_rep = chronicle.get("final_reputation", {}).get("east", 0.0)
	var west_rep = chronicle.get("final_reputation", {}).get("west", 0.0)
	var avg_rep = (east_rep + west_rep) / 2.0
	
	# Choose memorial type based on reputation
	var memorial_scene: PackedScene
	var memorial_pos = Vector2(-200, -20)  # Left side of castle
	
	if avg_rep < -0.3:
		# Very negative: Destroyed statue (or just book)
		memorial_scene = preload("res://Scenes/World/MemorialBook.tscn")
		print("[Game] Spawning memorial book (poor reputation)")
	elif avg_rep > 0.3:
		# Positive: Grand statue
		memorial_scene = preload("res://Scenes/World/MemorialStatue.tscn")
		print("[Game] Spawning memorial statue (good reputation)")
	else:
		# Neutral: Simple book
		memorial_scene = preload("res://Scenes/World/MemorialBook.tscn")
		print("[Game] Spawning memorial book (neutral reputation)")
	
	var memorial = memorial_scene.instantiate()
	memorial.position = memorial_pos
	add_child(memorial)
