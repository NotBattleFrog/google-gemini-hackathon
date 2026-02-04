extends Node2D

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
	# OLD SPAWNS REMOVED

	# Visuals: Add WorldEnvironment for Glow
	# Change player color to Ghostly Blue/White
	var player = find_child("Player", true, false)
	if player:
		player.modulate = Color(1.0, 1.0, 1.0, 0.8) # White Ghost
		
		
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
	
	# Add Journal UI - REMOVED for Mystery
	# var journal_scene = preload("res://Scenes/UI/Journal.tscn")
	# ...
	
	# --- MURDER MYSTERY SETUP ---
	
	# Add Mystery Manager
	var mystery_manager_script = load("res://Scripts/Managers/MysteryManager.gd")
	var mystery_manager = mystery_manager_script.new()
	mystery_manager.name = "MysteryManager"
	add_child(mystery_manager)
	
	# Add Ghost UI
	var ghost_ui_scene = preload("res://Scenes/UI/GhostUI.tscn")
	var ghost_ui = ghost_ui_scene.instantiate()
	add_child(ghost_ui)
	
	# Setup Atmosphere (House/Indoor)
	_setup_atmosphere()
	
	# Spawn NPCs for Mystery (Static positions)
	_spawn_mystery_npcs()
	
	print("[Game] Murder Mystery Mode Initialized")

func _spawn_mystery_npcs() -> void:
	# Clean existing enemies/units just in case
	get_tree().call_group("Units", "queue_free")
	get_tree().call_group("battle_enemies", "queue_free")
	
	await get_tree().process_frame
	
	var unit_scene = load("res://Scenes/Unit.tscn")
	
	# Detective (Center)
	var detective = unit_scene.instantiate()
	# Suspects (Line up)
	# Detective is at 0
	var positions = [Vector2(-120, 0), Vector2(120, 0), Vector2(240, 0)] # Specific slots
	# Better: Detective at -60? 
	# Let's do: Suspect 1 (-150), Detective (-50), Suspect 2 (50), Suspect 3 (150)
	
	detective.position = Vector2(-50, 0)
	detective.modulate = Color(0.8, 0.8, 0.9) # Silver/Chrome AI
	add_child(detective)
	detective.add_to_group("Units")
	
	positions = [Vector2(-150, 0), Vector2(50, 0), Vector2(150, 0)]
	# 1. Madam Vanna (Gold/Red) - Tycoon
	var vanna = unit_scene.instantiate()
	vanna.position = positions[0]
	vanna.modulate = Color(1.0, 0.8, 0.4) # Gold
	vanna.add_to_group("Units")
	add_child(vanna)
	
	# 2. Dr. Aris (Green/White) - Bio-Engineer
	var aris = unit_scene.instantiate()
	aris.position = positions[1]
	aris.modulate = Color(0.6, 1.0, 0.6) # Bio Green
	aris.add_to_group("Units")
	add_child(aris)

	# 3. Lila (Purple) - Daughter
	var lila = unit_scene.instantiate()
	lila.position = positions[2]
	lila.modulate = Color(0.7, 0.4, 1.0) # Purple
	lila.add_to_group("Units")
	add_child(lila)

func _setup_atmosphere() -> void:
	# Dark, indoor vibe
	RenderingServer.set_default_clear_color(Color(0.05, 0.05, 0.1))
	
	# Giant House Background
	var house_bg = ColorRect.new()
	house_bg.size = Vector2(800, 400)
	house_bg.position = Vector2(-400, -200) # Centered
	house_bg.color = Color(0.2, 0.15, 0.1) # Dark wood brown
	house_bg.name = "HouseBackground"
	add_child(house_bg)
	move_child(house_bg, 0) # Send to back
	
	# Floor
	var floor_rect = ColorRect.new()
	floor_rect.size = Vector2(800, 50)
	floor_rect.position = Vector2(-400, 40) # Under feet
	floor_rect.color = Color(0.1, 0.05, 0.02) # Darker floor
	add_child(floor_rect)
	
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
	

	
