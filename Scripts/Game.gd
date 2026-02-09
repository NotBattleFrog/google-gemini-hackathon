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
	GlobalSignalBus.game_started.emit()
	
	# Spawn Vagrant (Tutorial) - Disabled for Quota/Social Test
	# var vagrant = preload("res://Scenes/Vagrant.tscn").instantiate()
	# vagrant.position = Vector2(100, 0) # Near player start
	# add_child(vagrant)

	# Spawn Garrison for Social Test (Reduced for Quota)
	# OLD SPAWNS REMOVED

	# Visuals: Add WorldEnvironment for Glow
	# Player will be spawned with other characters in _spawn_mystery_npcs()

# Player is now spawned in _spawn_mystery_npcs() along with other characters
	
	# Setup camera for proper viewing
	_setup_camera()
		
		
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
  
	# Lamps removed - not needed for mystery scene
	
	# Add Journal UI - REMOVED for Mystery
	# var journal_scene = preload("res://Scenes/UI/Journal.tscn")
	# ...
	
	# --- MURDER MYSTERY SETUP ---
	
	# Add Turn-Based Game State Manager
	var turn_based_state_script = load("res://Scripts/Managers/TurnBasedGameState.gd")
	var turn_based_state = turn_based_state_script.new()
	turn_based_state.name = "TurnBasedGameState"
	add_child(turn_based_state)
	
	# Connect turn action completed signal
	if not GlobalSignalBus.turn_action_completed.is_connected(turn_based_state.on_character_action_completed):
		GlobalSignalBus.turn_action_completed.connect(turn_based_state.on_character_action_completed)
	
	# Add Ghost Action Input UI
	var ghost_action_ui_scene = preload("res://Scenes/UI/GhostActionInput.tscn")
	var ghost_action_ui = ghost_action_ui_scene.instantiate()
	add_child(ghost_action_ui)
	
	# Setup Atmosphere (House/Indoor)
	_setup_atmosphere()
	
	# Spawn NPCs for Mystery (Static positions)
	_spawn_mystery_npcs()
	
	# Add GameUI for HUD and API key panel (press K to open)
	var game_ui_scene = preload("res://Scenes/GameUI.tscn")
	var game_ui = game_ui_scene.instantiate()
	add_child(game_ui)
	print("[Game] GameUI loaded - Press K to open API Key settings")
	
	print("[Game] Murder Mystery Mode Initialized")

func _spawn_mystery_npcs() -> void:
	# Clean existing enemies/units just in case
	get_tree().call_group("Units", "queue_free")
	get_tree().call_group("battle_enemies", "queue_free")
	
	await get_tree().process_frame
	
	# Setup ground collision at the floor level (where characters should stand)
	_setup_ground_collision()
	
	var unit_scene = load("res://Scenes/Unit.tscn")
	
	# Position characters on the floor/platform area
	# Y position should match the ground collision
	# In Godot, Y increases downward, so positive Y is lower on screen
	# The room background floor should be visible around Y=280-300
	var floor_y = 280  # Floor level - moved down to be on visible floor
	
	# Spawn Player (Somchai) first - same way as NPCs, no special handling needed
	var player = unit_scene.instantiate()
	player.position = Vector2(-150, floor_y)  # Left side
	add_child(player)
	player.add_to_group("Units")
	player.add_to_group("Player")  # Also add to Player group for easy finding
	# Replace Unit script with Player script (which extends Unit, just adds turn-based init)
	var player_script = load("res://Scripts/Player.gd")
	if player_script:
		player.set_script(player_script)
		# Re-add to groups after script replacement (groups might be lost)
		player.add_to_group("Units")
		player.add_to_group("Player")
		print("[Game] Player script replaced, re-added to groups")
	# Assign name and sprite (same as NPCs)
	var player_soul = player.find_child("Soul", false, false)
	if player_soul:
		player_soul.personality.name = "Somchai"
		player_soul.personality.archetype = "Somchai"
		print("[Game] Player soul name set to: %s" % player_soul.personality.name)
	call_deferred("_setup_character_sprite", player, "Somchai.png")
	
	# Detective positioned between suspects
	var detective = unit_scene.instantiate()
	detective.position = Vector2(25, floor_y)
	add_child(detective)
	detective.add_to_group("Units")
	# Assign name and sprite
	var detective_soul = detective.find_child("Soul", false, false)
	if detective_soul:
		detective_soul.personality.name = "UNIT-7"
		detective_soul.personality.archetype = "UNIT-7"
	call_deferred("_setup_character_sprite", detective, "UNIT7.png")
	
	# Position characters in a line across the foreground of the room
	# Adjust positions to work with the room background (characters should be on the floor/platform)
	var positions = [Vector2(-200, floor_y), Vector2(-50, floor_y), Vector2(100, floor_y), Vector2(250, floor_y)]
	# 1. Madam Vanna (Gold/Red) - Tycoon
	var vanna = unit_scene.instantiate()
	vanna.position = positions[0]
	add_child(vanna)
	vanna.add_to_group("Units")
	var vanna_soul = vanna.find_child("Soul", false, false)
	if vanna_soul:
		vanna_soul.personality.name = "Madam Vanna"
		vanna_soul.personality.archetype = "Madam Vanna"
	call_deferred("_setup_character_sprite", vanna, "Madam_Vanna.png")
	
	# 2. Dr. Aris (Green/White) - Bio-Engineer
	var aris = unit_scene.instantiate()
	aris.position = positions[1]
	add_child(aris)
	aris.add_to_group("Units")
	var aris_soul = aris.find_child("Soul", false, false)
	if aris_soul:
		aris_soul.personality.name = "Dr. Aris"
		aris_soul.personality.archetype = "Dr. Aris"
	call_deferred("_setup_character_sprite", aris, "Dr_Aris.png")

	# 3. Lila (Purple) - Daughter
	var lila = unit_scene.instantiate()
	lila.position = positions[2]
	add_child(lila)
	lila.add_to_group("Units")
	var lila_soul = lila.find_child("Soul", false, false)
	if lila_soul:
		lila_soul.personality.name = "Lila"
		lila_soul.personality.archetype = "Lila"
	call_deferred("_setup_character_sprite", lila, "Lila.png")

func _setup_ground_collision() -> void:
	# Find or create ground collision
	var ground = find_child("Ground", false, false)
	if not ground:
		# Create ground if it doesn't exist
		ground = StaticBody2D.new()
		ground.name = "Ground"
		add_child(ground)
	
	# Remove old collision shapes
	for child in ground.get_children():
		if child is CollisionShape2D:
			child.queue_free()
	
	# Create ground collision at floor level
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(3000, 50)  # Wide enough to cover the room
	collision.shape = shape
	# Position at floor level - match the floor_y used for characters
	var floor_y = 280
	collision.position = Vector2(0, floor_y + 25)  # Position at floor level (floor_y + half height of collision)
	ground.add_child(collision)
	ground.collision_layer = 1  # Layer 1 for ground
	ground.collision_mask = 0  # Ground doesn't collide with anything
	print("[Game] Ground collision set up at Y: %d (floor_y: %d)" % [collision.position.y, floor_y])

func _setup_character_sprite(unit: Unit, sprite_filename: String) -> void:
	if not is_instance_valid(unit):
		push_error("Unit is not valid for sprite setup!")
		return
	
	# Find the Visuals node and Body ColorRect
	var visuals = unit.find_child("Visuals", false, false)
	if not visuals:
		push_warning("Unit %s has no Visuals node!" % unit.name)
		return
	
	var body_rect = visuals.find_child("Body", false, false)
	if body_rect:
		# Replace ColorRect with Sprite2D
		var sprite = Sprite2D.new()
		var texture = load("res://Assets/Characters/" + sprite_filename)
		if texture:
			sprite.texture = texture
			# Position sprite at origin (0,0) relative to Visuals, centered
			sprite.position = Vector2(0, 0)
			# Get texture size and scale appropriately
			var tex_size = texture.get_size()
			# Scale sprite to reasonable size (adjust as needed)
			# Character sprites should be visible but not too large
			# Assuming characters should be around 150-200 pixels tall on screen
			var target_height = 180.0
			var scale_factor = target_height / tex_size.y
			sprite.scale = Vector2(scale_factor, scale_factor)
			sprite.name = "BodySprite"
			sprite.z_index = 10  # Ensure characters are above background
			sprite.visible = true  # Explicitly make visible
			visuals.add_child(sprite)
			body_rect.queue_free()  # Remove the old ColorRect
			var char_name = unit.soul.personality.name if unit.soul else "Unknown"
			print("[Game] Set sprite for %s: %s (scale: %.2f, unit pos: %s, sprite pos: %s, visible: %s)" % [char_name, sprite_filename, scale_factor, unit.position, sprite.position, sprite.visible])
		else:
			push_error("Failed to load character sprite: res://Assets/Characters/%s" % sprite_filename)
	else:
		# If no Body ColorRect exists, create sprite directly
		var sprite = Sprite2D.new()
		var texture = load("res://Assets/Characters/" + sprite_filename)
		if texture:
			sprite.texture = texture
			sprite.position = Vector2(0, 0)
			var tex_size = texture.get_size()
			var target_height = 180.0
			var scale_factor = target_height / tex_size.y
			sprite.scale = Vector2(scale_factor, scale_factor)
			sprite.name = "BodySprite"
			sprite.z_index = 10
			sprite.visible = true
			visuals.add_child(sprite)
			var char_name = unit.soul.personality.name if unit.soul else "Unknown"
			print("[Game] Created sprite directly for %s: %s (no Body ColorRect found)" % [char_name, sprite_filename])
		else:
			push_error("Failed to load character sprite: res://Assets/Characters/%s" % sprite_filename)

func _setup_camera() -> void:
	# Add a camera to view the scene properly
	var camera = Camera2D.new()
	camera.name = "MainCamera"
	camera.position = Vector2(0, 0)  # Center of the room
	camera.zoom = Vector2(1.0, 1.0)  # Adjust zoom to fit the view
	camera.enabled = true
	camera.offset = Vector2(0, 0)  # No offset
	add_child(camera)
	# Make camera current so it's the active camera
	camera.make_current()
	print("[Game] Camera set up at position: %s, zoom: %s, current: %s" % [camera.position, camera.zoom, camera.is_current()])

func _setup_atmosphere() -> void:
	# Set background color to match room.png edges (dark blue/black)
	# This will only show if background doesn't cover everything
	RenderingServer.set_default_clear_color(Color(0.05, 0.05, 0.1))
	
	# Load and set room background image
	var room_texture = load("res://Assets/Backgrounds/room.png")
	if room_texture:
		var bg_sprite = Sprite2D.new()
		bg_sprite.texture = room_texture
		# Get texture size and scale appropriately
		var tex_size = room_texture.get_size()
		# Scale to fit viewport height (720) - crop sides if needed
		# This ensures we see floor to ceiling
		var viewport_height = 720.0
		var scale_factor = viewport_height / tex_size.y
		bg_sprite.scale = Vector2(scale_factor, scale_factor)
		
		# Position so center of image is at origin (Sprite2D centers by default)
		bg_sprite.position = Vector2(0, 0)
		bg_sprite.name = "RoomBackground"
		bg_sprite.z_index = -100  # Ensure it's behind everything
		bg_sprite.centered = true  # Ensure sprite is centered
		
		add_child(bg_sprite)
		move_child(bg_sprite, 0) # Send to back
		
		var scaled_width = tex_size.x * scale_factor
		var scaled_height = tex_size.y * scale_factor
		print("[Game] Room background loaded: original %s, scaled to %s, position: %s, scale: %s" % [tex_size, Vector2(scaled_width, scaled_height), bg_sprite.position, bg_sprite.scale])
	else:
		push_error("Failed to load room.png background!")
		# Fallback to dark background
		var fallback_bg = ColorRect.new()
		fallback_bg.size = Vector2(2000, 1000)
		fallback_bg.position = Vector2(-1000, -500)
		fallback_bg.color = Color(0.05, 0.05, 0.1)
		fallback_bg.name = "FallbackBackground"
		add_child(fallback_bg)
		move_child(fallback_bg, 0)

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
	

	
