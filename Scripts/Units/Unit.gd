class_name Unit
extends CharacterBody2D

enum State { IDLE, WORK, COMBAT, MUTINY, RETREAT, SOCIALIZING }

# Config
@export var speed: float = 50.0
@export var faction: String = "FRIENDLY" # Default to Friendly for Garrison test

# State
var current_state: State = State.IDLE
var soul: SoulComponent
var conversation_partner: Unit = null
var social_check_timer: Timer

const SOCIAL_CHECK_INTERVAL: float = 5.0  # Check for partners every 5 seconds

func _ready() -> void:
	soul = find_child("Soul", false, false)
	if not soul:
		push_warning("Unit %s missing SoulComponent! Creating default." % name)
		soul = SoulComponent.new()
		soul.name = "Soul"
		add_child(soul)
	
	# Initialize basic behavior
	# For Garrison test, let them wander randomly nearby
	velocity.x = randf_range(-20, 20)
	
	# Create Social Detection Area
	var area = Area2D.new()
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 300 # Increased to 300 (Massive range)
	shape.shape = circle
	area.add_child(shape)
	# Detect Layer 3 (Enemy/Unit) + Layer 1 (Player?)
	# Value 4 is Layer 3. Value 5 is Layer 1 + 3 ?
	# Let's just set it to match typical unit layers.
	area.collision_mask = 7 # Layers 1, 2, 3
	add_child(area)
	area.body_entered.connect(_on_social_area_entered)
	area.body_exited.connect(_on_social_area_exited)
	
	# Setup periodic social check timer
	social_check_timer = Timer.new()
	social_check_timer.wait_time = SOCIAL_CHECK_INTERVAL
	social_check_timer.one_shot = false
	social_check_timer.timeout.connect(_check_for_socialization)
	add_child(social_check_timer)
	social_check_timer.start()
	
	_setup_cooldown_label()

func _exit_tree() -> void:
	# Clean up references to prevent memory leaks
	for unit in nearby_units:
		if is_instance_valid(unit):
			pass  # Could disconnect signals if needed
	nearby_units.clear()
	conversation_partner = null

var hp: float = 3.0
var cooldown_label: Label

var _last_debug_state: int = -1
var _last_neighbor_count: int = -1

func _setup_cooldown_label() -> void:
	cooldown_label = Label.new()
	cooldown_label.position = Vector2(-20, -85) # Above bubble
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_color_override("font_color", Color.YELLOW)
	cooldown_label.add_theme_font_size_override("font_size", 12)
	add_child(cooldown_label)

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	queue_free()

const BUBBLE_SCENE = preload("res://Scenes/UI/DialogueBubble.tscn")

func talk(message: String, emotion: String = "NEUTRAL") -> void:
	var bubble = BUBBLE_SCENE.instantiate()
	add_child(bubble)
	bubble.position = Vector2(0, -60) # Above head
	bubble.speak(message, emotion)

func _physics_process(delta: float) -> void:
	# Only update label when state/count changes
	var neighbor_count = nearby_units.size()
	
	if current_state != _last_debug_state or neighbor_count != _last_neighbor_count:
		_last_debug_state = current_state
		_last_neighbor_count = neighbor_count
		update_debug_label()

	# Global Mutiny Check
	if soul.personality.loyalty < 0.1 and current_state != State.MUTINY:
		enter_state(State.MUTINY)
		talk("Down with the Crown!", "ANGER")
		
	match current_state:
		State.IDLE:
			velocity.y += 980 * delta # Gravity
			
			# Improved Wander: Randomly switch between moving and stopping
			if randf() < 0.02: # 2% chance to change plan
				if randf() < 0.5:
					velocity.x = 0 # Stop
				else:
					velocity.x = randf_range(-30, 30) # Walk
			
			move_and_slide()
			
			# Fallback: Query Area if we think we are alone
			if nearby_units.is_empty():
				var area = find_child("Area2D", false, false) # By type usually? No, I added it as child.
				# Actually I didn't name it. Let's find by type or iteration.
				for child in get_children():
					if child is Area2D:
						var bodies = child.get_overlapping_bodies()
						for b in bodies:
							if b is Unit and b != self and not b in nearby_units:
								nearby_units.append(b)
			
			# Socialization check now handled by timer (every 5 seconds)
			
		State.SOCIALIZING:
			velocity.x = 0
			velocity.y += 980 * delta
			move_and_slide()
			
		State.COMBAT:
			velocity.x = 0
			
		State.MUTINY:
			# Attack Castle logic (simplified)
			move_and_slide()

var nearby_units: Array[Unit] = []

func _on_social_area_entered(body: Node) -> void:
	if body is Unit and body != self:
		nearby_units.append(body)

func _on_social_area_exited(body: Node) -> void:
	if body is Unit and body in nearby_units:
		nearby_units.erase(body)

func _check_for_socialization() -> void:
	if not soul.can_socialize(): return
	
	# Simple check: pick random neighbor
	# In real game, filter by distance, checking their state, etc.
	# Clean up invalid refs first
	nearby_units = nearby_units.filter(func(u): return is_instance_valid(u))
	
	if nearby_units.is_empty():
		# print("Unit %s checked for partner, but nobody nearby." % name)
		return
	
	var partner = nearby_units.pick_random()
	print("Unit %s found potential partner %s." % [name, partner.name])
	
	if partner.soul.can_socialize() and partner.current_state == State.IDLE:
		print("Both %s and %s are ready to socialize! Initiating..." % [name, partner.name])
		enter_state(State.SOCIALIZING)
		partner.enter_state(State.SOCIALIZING)
		
		conversation_partner = partner
		partner.conversation_partner = self
		
		# Initiate
		soul.initiate_social_interaction(partner.soul)
	else:
		print("Partner %s is busy or on cooldown." % partner.name)

# Called by Soul when LLM returns dialogue
func play_dialogue_sequence(dialogue_list: Array, partner: Unit) -> void:
	print("[Unit] play_dialogue_sequence called with ", dialogue_list.size(), " lines")
	# This needs to be a coroutine to play lines in sequence
	start_dialogue_routine(dialogue_list)

func start_dialogue_routine(dialogue_list: Array) -> void:
	print("[Unit] start_dialogue_routine started")
	for line in dialogue_list:
		var speaker_label = line.get("speaker", "A")
		var text = line.get("text", "...")
		
		print("[Unit] Speaking line: ", speaker_label, " -> ", text)
		
		# Determine who speaks
		# "A" is initiator (us), "B" is partner
		if speaker_label == "A":
			talk(text)
		elif conversation_partner and is_instance_valid(conversation_partner):
			conversation_partner.talk(text)
			
		# Wait for bubble duration (approx 3-4s)
		await get_tree().create_timer(3.5).timeout
		
	# Back to IDLE
	enter_state(State.IDLE)
	if conversation_partner:
		conversation_partner.enter_state(State.IDLE)
		conversation_partner = null

# Eavesdropping System
func notify_eavesdroppers(partner: Unit, dialogue_summary: String) -> void:
	if not soul or not partner:
		return
	
	print("[Unit] %s notifying eavesdroppers about conversation" % name)
	
	for nearby in nearby_units:
		if nearby == partner or nearby == self:
			continue
		if not is_instance_valid(nearby):
			continue
		if nearby.current_state == State.IDLE and nearby.soul:
			# Notify them of overhearing
			nearby.soul.overhear_conversation(self.soul, partner.soul, dialogue_summary)
			print("[Unit] -> %s overheard the conversation" % nearby.name)

func update_debug_label() -> void:
	var state_str = State.keys()[current_state]
	var debug_text = "%s\nN: %d" % [state_str, _last_neighbor_count]
	
	if soul and not soul.can_socialize():
		debug_text += "\nCD"
		cooldown_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		cooldown_label.add_theme_color_override("font_color", Color.WHITE)
	
	cooldown_label.text = debug_text
	cooldown_label.visible = true

func enter_state(new_state: State) -> void:
	current_state = new_state
	update_debug_label()  # Update label immediately on state change
	# print("%s entered state: %s" % [name, State.keys()[new_state]])
	
	if new_state == State.MUTINY:
		modulate = Color(1, 0, 0)
		LoreManager.call("add_event", "%s mutinied against the crown!" % name)
