class_name Unit
extends CharacterBody2D

enum State { IDLE, WORK, COMBAT, MUTINY, RETREAT, SOCIALIZING }

# Signals
signal dialogue_completed()

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
	# Static - do nothing
	
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
	
	# Social check timer removed - turn-based system handles all interactions
	# No need to find partners or check if busy - characters speak to everyone during their turn
	
	_setup_cooldown_label()

func _exit_tree() -> void:
	# Clean up references to prevent memory leaks
	for unit in nearby_units:
		if is_instance_valid(unit):
			pass  # Could disconnect signals if needed
	nearby_units.clear()
	conversation_partner = null

var hp: float = 3.0
var name_label: Label = null

var _last_debug_state: int = -1
var _last_neighbor_count: int = -1
var is_grounded: bool = false  # Performance: Track if character is on ground to skip gravity

func _setup_cooldown_label() -> void:
	name_label = Label.new()
	name_label.position = Vector2(-30, -85) # Above bubble
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 14)
	add_child(name_label)

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	queue_free()

const BUBBLE_SCENE = preload("res://Scenes/UI/DialogueBubble.tscn")
var current_bubble: Node = null  # Track current bubble for clearing
# PERFORMANCE: Bubble pooling to reduce allocations
var bubble_pool: Array[Node] = []
const MAX_POOL_SIZE: int = 3

func _get_pooled_bubble() -> Node:
	# Try to reuse a bubble from the pool
	if bubble_pool.size() > 0:
		var bubble = bubble_pool.pop_back()
		bubble.visible = true
		return bubble
	# Pool empty, create new one
	return BUBBLE_SCENE.instantiate()

func _return_bubble_to_pool(bubble: Node) -> void:
	# Return bubble to pool instead of destroying
	if bubble_pool.size() < MAX_POOL_SIZE:
		bubble.visible = false
		bubble_pool.append(bubble)
	else:
		bubble.queue_free()

func clear_speech_bubbles() -> void:
	# Return all dialogue bubbles to pool instead of destroying
	for child in get_children():
		if child is DialogueBubble or child.name == "DialogueBubble":
			_return_bubble_to_pool(child)
			remove_child(child)
	current_bubble = null

func talk(message: String, emotion: String = "NEUTRAL") -> void:
	# Clear any existing bubbles first
	clear_speech_bubbles()
	var bubble = _get_pooled_bubble()
	add_child(bubble)
	bubble.position = Vector2(0, -60) # Above head
	bubble.speak(message, emotion)
	current_bubble = bubble

func show_thought(message: String) -> void:
	# Clear any existing bubbles first
	clear_speech_bubbles()
	var bubble = _get_pooled_bubble()
	add_child(bubble)
	bubble.position = Vector2(0, -60) # Above head
	bubble.speak(message, "THOUGHT")  # Use thought style
	current_bubble = bubble
	# Could add visual distinction for thoughts (different color, italic, etc.)

func show_whisper(message: String, target_name: String = "") -> void:
	# Clear any existing bubbles first
	clear_speech_bubbles()
	var bubble = _get_pooled_bubble()
	add_child(bubble)
	bubble.position = Vector2(0, -60) # Above head
	bubble.speak(message, "WHISPER")  # Use whisper style
	current_bubble = bubble
	# Could add visual distinction for whispers (smaller, grayed out, etc.)

func _physics_process(delta: float) -> void:
	# Only update label when state/count changes
	var neighbor_count = nearby_units.size()
	
	if current_state != _last_debug_state or neighbor_count != _last_neighbor_count:
		_last_debug_state = current_state
		_last_neighbor_count = neighbor_count
		update_debug_label()

	# Global Mutiny Check
	if soul and soul.personality and soul.personality.loyalty < 0.1 and current_state != State.MUTINY:
		enter_state(State.MUTINY)
		talk("Down with the Crown!", "ANGER")
		
	match current_state:
		State.IDLE:
			# PERFORMANCE OPTIMIZATION: Skip physics if already grounded
			if is_grounded:
				# Character is stable on ground, no need for continuous physics
				return
			
			# STATIC MODE: No movement, but apply gravity for collision
			velocity.x = 0
			velocity.y += 980 * delta # Gravity ensures they stay on floor
			
			move_and_slide()
			
			# If we're on the floor, mark as grounded to skip future physics
			if is_on_floor():
				velocity.y = 0
				is_grounded = true  # Performance: Stop processing physics once grounded
			
			# REMOVED: Expensive fallback Area2D query - this was running every frame!
			# nearby_units are now managed solely by Area2D signals which is much more efficient
			
		State.SOCIALIZING:
			velocity.x = 0
			velocity.y += 980 * delta
			move_and_slide()
			if is_on_floor():
				velocity.y = 0
			
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
	# Disabled - turn-based system handles all character interactions
	# Characters speak to everyone during their turn, no partner finding needed
	pass

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
	
	# Notify MysteryManager that dialogue is done
	dialogue_completed.emit()
	print("[Unit] Dialogue sequence completed, signal emitted")

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
	if name_label == null or not is_instance_valid(name_label):
		return  # Label not initialized yet
	if soul and soul.personality:
		name_label.text = soul.personality.get("name", "Unknown")
	else:
		name_label.text = "Unit"
	name_label.visible = true

func enter_state(new_state: State) -> void:
	current_state = new_state
	update_debug_label()  # Update label immediately on state change
	# print("%s entered state: %s" % [name, State.keys()[new_state]])
	
	if new_state == State.MUTINY:
		modulate = Color(1, 0, 0)
		LoreManager.call("add_event", "%s mutinied against the crown!" % name)
