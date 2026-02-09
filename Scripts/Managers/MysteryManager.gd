extends Node
class_name MysteryManager

# Signals
signal phase_changed(phase: String) # "CONVERSATION", "GHOST_TURN"
signal ghost_turn_started()
signal ghost_turn_ended()
signal queue_updated(queue: Array)
signal progress_updated(turns_left: int)

# Config
const CONVOS_BEFORE_INTERRUPT: int = 5

# State
var conversation_count: int = 0
var conversation_queue: Array[Array] = [] # Array of [UnitA, UnitB] pairs
var is_ghost_turn: bool = false
var detective: Unit
var suspects: Array[Unit] = []
var ghost_message_target: Unit = null
var ghost_message_text: String = ""

func _ready() -> void:
	print("[MysteryManager] Initialized")
	# Wait for units to spawn - use a longer delay to ensure units are ready
	await get_tree().create_timer(0.5).timeout
	call_deferred("_setup_mystery")

func _setup_mystery() -> void:
	print("[MysteryManager] Setting up mystery scene...")
	
	# Find Units
	var units = get_tree().get_nodes_in_group("Units")
	if units.size() < 4:
		print("[MysteryManager] WARNING: Not enough units found! Needs 4 (1 Detective + 3 Suspects). Found: ", units.size())
		return
		
	# Assign Roles
	# Assign Roles with Depth
	detective = units[0]
	_assign_role(detective, "UNIT-7", "Logical AI", "scanning scene", "", "Unaware Killer")
	
	var archetypes = [
		{
			"name": "Madam Vanna",
			"trait": "Tech Tycoon - Calculating",
			"state": "Panicked Desperation",
			"secret": "Trying to steal Source Code.",
			"conflict": "Incentive: Death Clause funding. Needs code."
		},
		{
			"name": "Dr. Aris",
			"trait": "Bio-Engineer - Cold Fury",
			"state": "Analyzing Logs",
			"secret": "Trying to clean Neural Logs.",
			"conflict": "Incentive: Project Cancellation. Used own tech?"
		},
		{
			"name": "Lila",
			"trait": "Estranged Daughter - Grief",
			"state": "Weeping",
			"secret": "Searching for Mother's Digital Mind.",
			"conflict": "Incentive: Inheritance. Emotional outbursts."
		}
	]
	
	for i in range(1, units.size()):
		if i-1 < archetypes.size():
			var data = archetypes[i-1]
			var suspect = units[i]
			suspects.append(suspect)
			_assign_role(suspect, data.name, data.trait, data.state, data.secret, data.conflict)
	
	print("[MysteryManager] Roles assigned. Detective: %s, Suspects: %d" % [detective.name, suspects.size()])
	
	# Start Queuing
	_generate_conversation_queue()
	_process_queue()

func _assign_role(unit: Unit, role_name: String, npc_trait: String, state_desc: String, secret: String, conflict: String) -> void:
	unit.soul.personality.archetype = role_name # Name
	unit.soul.personality.role = "Suspect" if secret != "" else "Detective"
	unit.soul.personality.traits = [npc_trait]
	unit.soul.personality.name = role_name
	
	# Store deep mind info in personality dictionary (requires updating Soul/Personality struct or just dynamic)
	unit.soul.personality["secret"] = secret
	unit.soul.personality["conflict"] = conflict
	
	unit.update_debug_label() # Refresh label

func _generate_conversation_queue() -> void:
	# Generate random pairings
	conversation_queue.clear()
	
	var all_units = suspects.duplicate()
	all_units.append(detective)
	
	# Generate 10 random conversations
	for i in range(10):
		var unit_a = all_units.pick_random()
		var unit_b = all_units.pick_random()
		
		# Retry if self-talk
		while unit_b == unit_a:
			unit_b = all_units.pick_random()
			
		conversation_queue.append([unit_a, unit_b])

	queue_updated.emit(conversation_queue) # Emit update
	print("[MysteryManager] Generated queue of %d conversations" % conversation_queue.size())

func _process_queue() -> void:
	if is_ghost_turn:
		return
		
	if conversation_queue.is_empty():
		_generate_conversation_queue()
	
	# ... (Ghost Check) ...
	if conversation_count > 0 and conversation_count % CONVOS_BEFORE_INTERRUPT == 0:
		_start_ghost_turn()
		return

	# Get next pair
	var pair = conversation_queue.pop_front()
	queue_updated.emit(conversation_queue) # Emit update after pop
	var unit_a = pair[0]
	var unit_b = pair[1]
	
	# Trigger Conversation
	print("[MysteryManager] Triggering conversation %d: %s <-> %s" % [conversation_count + 1, unit_a.name, unit_b.name])
	
	# Update Countdown
	var turns_left = CONVOS_BEFORE_INTERRUPT - (conversation_count % CONVOS_BEFORE_INTERRUPT)
	progress_updated.emit(turns_left)
	
	_force_conversation(unit_a, unit_b)

func _on_conversation_completed() -> void:
	print("[MysteryManager] Dialogue completed, proceeding to next conversation")
	# Process next conversation
	_process_queue()

func _force_conversation(unit_a: Unit, unit_b: Unit) -> void:
	# Inject ghost message if applicable
	var extra_context = ""
	if ghost_message_target and (unit_a == ghost_message_target or unit_b == ghost_message_target):
		extra_context = "\n[GHOST INFLUENCE] You feel compelled to say: '%s'" % ghost_message_text
		# Only apply once
		ghost_message_target = null
		ghost_message_text = ""
		print("[MysteryManager] Applied ghost influence!")
	
	# Connect to dialogue_completed signal (one-shot using CONNECT_ONE_SHOT flag)
	unit_a.dialogue_completed.connect(_on_conversation_completed, CONNECT_ONE_SHOT)
	
	# Initiate conversation
	unit_a.soul.initiate_social_interaction(unit_b.soul, extra_context)
	conversation_count += 1


func _start_ghost_turn() -> void:
	print("[MysteryManager] 👻 GHOST TURN START 👻")
	is_ghost_turn = true
	ghost_turn_started.emit()
	phase_changed.emit("GHOST_TURN")
	
	# UI will catch this signal and show options

func submit_ghost_action(target_suspect_index: int, message: String) -> void:
	print("[MysteryManager] Ghost Action Submitted: Index %d, Msg '%s'" % [target_suspect_index, message])
	
	if target_suspect_index >= 0 and target_suspect_index < suspects.size():
		ghost_message_target = suspects[target_suspect_index]
		ghost_message_text = message
	elif target_suspect_index == -1: # Detective?
		ghost_message_target = detective
		ghost_message_text = message
		
	is_ghost_turn = false
	conversation_count += 1 # Advance count so we don't loop weirdly on modulo
	ghost_turn_ended.emit()
	phase_changed.emit("CONVERSATION")
	
	# Resume immediately
	_process_queue()
