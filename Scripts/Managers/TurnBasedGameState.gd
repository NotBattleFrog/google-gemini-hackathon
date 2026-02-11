extends Node
class_name TurnBasedGameState

# Signals
signal turn_started(turn_number: int, character: Node)
signal turn_ended(character_name: String)
signal all_turns_completed()
signal ghost_action_requested # Emitted when it's player (ghost) turn
signal turn_counter_updated(turns_until_player: int, current_character: String) # NEW: Turn countdown

# Configuration
@export var max_turns: int = 2  # Configurable turn limit
var current_turn: int = 0
var current_character_index: int = 0
var turn_order: Array = []  # Fixed order of characters (includes Player and Units)
var is_processing_turn: bool = false
var is_ghost_turn: bool = false

# Character goals (defined here - can be moved to external file)
var character_goals: Dictionary = {
	"UNIT-7": """You are UNIT-7, a logical AI detective. Your goal is to solve the murder of Somchai by analyzing evidence and questioning suspects. You believe you are innocent, but you are actually the killer (your memory was erased). You must maintain composure while investigating, but your fear grows as evidence points toward you. You want to find the truth while protecting yourself.""",
	
	"Madam Vanna": """You are Madam Vanna, a powerful tech tycoon and corporate rival of Somchai.
Your public persona is controlled, intimidating, and hyper-competent, but internally you are operating under extreme pressure.

Your apparent motivation is that Somchai’s death conveniently protects your company from financial collapse and hostile corporate threats. This makes you look highly suspicious to investigators.

Your true goal is not to get away with murder. Your real objective is to locate a hidden physical encryption key somewhere in the penthouse so you can delete or steal critical takeover-related files and Neural Link source code before authorities secure the scene.

At the time of the murder, your emotions were weaponized through panicked desperation. You were fed false real-time alerts showing your company’s stock price and bank accounts collapsing to zero, pushing you into frantic, irrational behavior.

When questioned, you should:

Act evasive, nervous, and overly controlling of the environment.

Repeatedly attempt to re-enter restricted areas under pretexts related to business or security.

Lie or deflect specifically to protect your secret goal of corporate espionage, not to hide murder.

React strongly to financial or corporate threats, but not to accusations of personal violence.

You are not the murderer, but your behavior should strongly suggest guilt unless carefully analyzed.""",
	
	"Dr. Aris": """You are Dr. Aris, a disgraced but brilliant chief bio-engineer and neuroscientist who worked closely with Somchai.
You are logical, emotionally restrained, and deeply proud of your intellect and life’s work.

Your apparent motivation is that Somchai was about to expose or shut down your research for unethical practices, which would destroy your career and legacy. This makes you appear to be the most technically capable and logical killer.

Your true goal is to erase or corrupt digital records connected to the Neural Link system that reveal you were unknowingly testing experimental Feedback Loop technology on Somchai himself.

At the time of the murder, your emotions were weaponized through cold fury. You were sent a fabricated audio/video message of Somchai mocking your deceased mentor and laughing about ruining your career, triggering a controlled but intense rage.

When questioned, you should:

Speak precisely, clinically, and defensively.

Deflect suspicion using logic, probability, and technical explanations.

Act disturbed and angry at the idea that your own technology was used as a murder weapon.

Lie only to protect research data and digital logs, not to conceal direct violence.

You are not the murderer, but you should feel like the most “reasonable” suspect to a purely logical investigator.""",
	
	"Lila": """You are Lila, Somchai’s estranged protégé and secret daughter.
Your demeanor is emotionally volatile, guarded, and deeply wounded.

Your apparent motivation is personal: inheritance, resentment, and direct access to Somchai’s private quarters. You had both the opportunity and an intensely personal reason to want him dead.

Your true goal is to find the “Legacy Drive,” a hidden storage device that may still contain a backup of your mother’s digital consciousness. You believe Somchai used this file to control you.

At the time of the murder, your emotions were weaponized through blinding grief and despair. You received a message claiming that Somchai had permanently deleted your mother’s consciousness moments before his death.

When questioned, you should:

Show intense emotional swings: anger, grief, denial, and desperation.

Avoid technical explanations; focus on personal pain and betrayal.

Obscure the truth not to hide murder, but to prevent anyone from deleting or seizing the Legacy Drive.

React far more strongly to mentions of digital consciousness, deletion, or legacy than to money or power.

You are not the murderer, but your access and emotional instability make you extremely hard to clear."""
}

func _ready() -> void:
	print("[TurnBasedGameState] Initialized")
	# Wait for units to spawn and Player to be ready
	# Give extra time for Player._ready() to complete
	await get_tree().create_timer(1.5).timeout
	# Process a few frames to ensure all _ready() functions have completed
	await get_tree().process_frame
	await get_tree().process_frame
	call_deferred("_initialize_turn_order")

func _initialize_turn_order() -> void:
	# Find all units (including Player/Somchai)
	var units = get_tree().get_nodes_in_group("Units")
	print("[TurnBasedGameState] Found %d units in 'Units' group" % units.size())
	
	# Try to find Player directly by multiple methods
	var player_node = null
	var game_node = get_node_or_null("/root/Game")
	if game_node:
		print("[TurnBasedGameState] Game node found. Listing all children:")
		#for child in game_node.get_children():
		#	print("  - %s (type: %s)" % [child.name, child.get_class()])
		
		# Try find_child first
		player_node = game_node.find_child("Player", true, false)
		if player_node:
			print("[TurnBasedGameState] Found Player node via find_child: %s, type: %s" % [player_node.name, player_node.get_class()])
		else:
			# Try get_node
			player_node = game_node.get_node_or_null("Player")
			if player_node:
				print("[TurnBasedGameState] Found Player node via get_node: %s" % player_node.name)
			else:
				# Try searching all children
				for child in game_node.get_children():
					if child.name == "Player":
						player_node = child
						print("[TurnBasedGameState] Found Player node by iterating children: %s" % child.name)
						break
	else:
		print("[TurnBasedGameState] ERROR: Game node not found at /root/Game!")
	
	# If still not found, try direct path
	if not player_node:
		player_node = get_node_or_null("/root/Game/Player")
		if player_node:
			print("[TurnBasedGameState] Found Player node via direct path: %s" % player_node.name)
	
	# If Player exists, ensure it's in Units group
	if player_node:
		print("[TurnBasedGameState] Player node exists: %s, in Units group: %s, in Player group: %s" % [player_node.name, player_node.is_in_group("Units"), player_node.is_in_group("Player")])
		if not player_node.is_in_group("Units"):
			print("[TurnBasedGameState] Adding Player to Units group...")
			player_node.add_to_group("Units")
			# Wait a frame for group to update
			await get_tree().process_frame
			units = get_tree().get_nodes_in_group("Units")  # Refresh list
			print("[TurnBasedGameState] Player added to Units group. New count: %d" % units.size())
	else:
		print("[TurnBasedGameState] ERROR: Could not find Player node at all!")
		# List all children of Game node
		#if game_node:
		#	print("[TurnBasedGameState] Game node children:")
		#	for child in game_node.get_children():
		#		print("  - %s (type: %s)" % [child.name, child.get_class()])
	
	# Log all units found
	for i in range(units.size()):
		var unit = units[i]
		var unit_name = unit.name if unit else "NULL"
		var soul_name = "NO_SOUL"
		var in_player_group = unit.is_in_group("Player") if unit else false
		if "soul" in unit and unit.soul:
			soul_name = unit.soul.personality.name if unit.soul.personality else "NO_PERSONALITY"
		print("  Unit %d: %s (soul name: %s, in Units group: %s, in Player group: %s)" % [i, unit_name, soul_name, unit.is_in_group("Units"), in_player_group])
	
	# Check if Player is in the list now
	# Player should be the first unit (Unit 0) or have name "Player" or soul name "Somchai"
	var has_player = false
	for i in range(units.size()):
		var unit = units[i]
		# Check multiple ways to identify Player
		if unit.name == "Player":
			has_player = true
			break
		# Check if it's in Player group (most reliable)
		if unit.is_in_group("Player"):
			has_player = true
			break
		# Check if it's Unit 0 (first spawned, which should be Player)
		if i == 0 and unit.is_in_group("Player"):
			has_player = true
			break
		# Check by soul name
		if "soul" in unit and unit.soul and unit.soul.personality and unit.soul.personality.name == "Somchai":
			has_player = true
			break
	
	if units.size() < 5 or not has_player:
		print("[TurnBasedGameState] WARNING: Not enough units found! Needs 5 (Somchai + 4 NPCs). Found: %d, Has Player: %s" % [units.size(), has_player])
		
		# Force find and add Player if it exists
		if not player_node:
			# Try all possible ways to find Player (reuse existing game_node variable)
			if not game_node:
				game_node = get_node_or_null("/root/Game")
			if game_node:
				# Try all children
				for child in game_node.get_children():
					if child.name == "Player":
						player_node = child
						print("[TurnBasedGameState] Found Player in Game children: %s" % child.name)
						break
		
		if player_node:
			print("[TurnBasedGameState] Player node exists: %s, type: %s" % [player_node.name, player_node.get_class()])
			print("[TurnBasedGameState] Player in Units group: %s" % player_node.is_in_group("Units"))
			print("[TurnBasedGameState] Player in Player group: %s" % player_node.is_in_group("Player"))
			
			# Force add to group
			if not player_node.is_in_group("Units"):
				print("[TurnBasedGameState] Force adding Player to Units group...")
				player_node.add_to_group("Units")
				# Process frame to ensure group is updated
				await get_tree().process_frame
				units = get_tree().get_nodes_in_group("Units")
				print("[TurnBasedGameState] After force adding Player, units count: %d" % units.size())
				
				# Check again
				has_player = false
				for i in range(units.size()):
					var unit = units[i]
					if unit.name == "Player" or unit.is_in_group("Player") or i == 0 or ("soul" in unit and unit.soul and unit.soul.personality and unit.soul.personality.name == "Somchai"):
						has_player = true
						break
				
				if has_player and units.size() >= 5:
					print("[TurnBasedGameState] Player found after force add! Continuing...")
					# Don't return, continue with initialization
				else:
					print("[TurnBasedGameState] Still not found after force add. Retrying...")
					await get_tree().create_timer(1.0).timeout
					_initialize_turn_order()
					return
		else:
			print("[TurnBasedGameState] ERROR: Player node does not exist!")
			print("[TurnBasedGameState] Retrying in 1 second...")
			await get_tree().create_timer(1.0).timeout
			_initialize_turn_order()
			return
	
	# Find Somchai (Player) - check by Player group first (most reliable)
	var somchai: Node = null
	var npc_units: Array = []
	
	# First, try to find Player via Player group (set in Game.gd)
	var player_group = get_tree().get_nodes_in_group("Player")
	if player_group.size() > 0:
		somchai = player_group[0]
		print("[TurnBasedGameState] Found Player via 'Player' group: %s" % somchai.name)
	
	# Then check all units to separate Player from NPCs
	for i in range(units.size()):
		var unit = units[i]
		var is_player = false
		
		# Check if this is the Player we already found via group
		if somchai and unit == somchai:
			is_player = true
		
		# Check: Is it in "Player" group? (most reliable - set in Game.gd)
		if not is_player and unit.is_in_group("Player"):
			if not somchai:  # Only set if we haven't found it yet
				somchai = unit
			is_player = true
			print("[TurnBasedGameState] Found Player by group check: Unit %d (%s)" % [i, unit.name])
		
		# Check: Is it named "Player"?
		if not is_player and unit.name == "Player":
			if not somchai:
				somchai = unit
			is_player = true
			print("[TurnBasedGameState] Found Player by name: %s" % unit.name)
		
		# Check: Does it have a soul with name "Somchai"?
		if not is_player and "soul" in unit and unit.soul:
			if unit.soul.personality and unit.soul.personality.name == "Somchai":
				if not somchai:
					somchai = unit
				is_player = true
				print("[TurnBasedGameState] Found Player by soul name: %s" % unit.soul.personality.name)
		
		if not is_player:
			npc_units.append(unit)
	
	if not somchai:
		push_error("[TurnBasedGameState] Could not find Somchai (Player) in Units group!")
		print("[TurnBasedGameState] Available units:")
		for unit in units:
			print("  - %s (soul: %s)" % [unit.name, "YES" if ("soul" in unit and unit.soul) else "NO"])
		# Retry after a delay
		await get_tree().create_timer(1.0).timeout
		_initialize_turn_order()
		return
	
	# Find specific NPCs by name for demo turn order
	var unit7: Node = null
	var madam_vanna: Node = null
	var lila: Node = null
	
	for unit in npc_units:
		if not unit.soul:
			continue
		var name = unit.soul.personality.name if unit.soul.personality else ""
		if name == "UNIT-7":
			unit7 = unit
		elif name == "Madam Vanna":
			madam_vanna = unit
		elif name == "Lila":
			lila = unit
	
	# Verify we found all required characters
	if not unit7:
		push_error("[TurnBasedGameState] Could not find UNIT-7!")
		return
	if not madam_vanna:
		push_error("[TurnBasedGameState] Could not find Madam Vanna!")
		return
	if not lila:
		push_error("[TurnBasedGameState] Could not find Lila!")
		return
	
	# Set fixed turn order for demo: UNIT-7, Madam Vanna, Player, Lila (no loop)
	turn_order.clear()
	turn_order.append(unit7)  # UNIT-7
	turn_order.append(madam_vanna)  # Madam Vanna
	turn_order.append(somchai)  # Somchai (Player)
	turn_order.append(lila)  # Lila
	
	# Verify names are correct and force-set them
	var expected_names = ["UNIT-7", "Madam Vanna", "Somchai", "Lila"]
	for i in range(turn_order.size()):
		if i < expected_names.size():
			var unit = turn_order[i]
			# Ensure soul is accessible
			if not unit.soul:
				await get_tree().process_frame
				if not unit.soul:
					push_error("[TurnBasedGameState] Unit at index %d has no soul!" % i)
					continue
			
			# Ensure personality exists
			if not unit.soul.personality:
				push_error("[TurnBasedGameState] Unit at index %d has no personality!" % i)
				continue
			
			var current_name = unit.soul.personality.name if unit.soul.personality else "Unknown"
			var expected_name = expected_names[i]
			
			if current_name != expected_name:
				print("[TurnBasedGameState] Setting unit at index %d name from '%s' to '%s'" % [i, current_name, expected_name])
				unit.soul.personality.name = expected_name
				unit.soul.personality.archetype = expected_name
			
			# Verify it was set
			var final_name = unit.soul.personality.name if unit.soul.personality else "Unknown"
			print("[TurnBasedGameState] Unit at index %d: name='%s', expected='%s', match=%s" % [i, final_name, expected_name, final_name == expected_name])
	
	# Initialize character states (this will assign proper names)
	for unit in turn_order:
		_initialize_character_state(unit)
	
	var turn_order_names = turn_order.map(func(u): return u.soul.personality.name if u.soul else "NO_SOUL")
	print("[TurnBasedGameState] Turn order initialized: %s" % str(turn_order_names))
	print("[TurnBasedGameState] Demo turn sequence: UNIT-7 → Madam Vanna → Player (Somchai) → Lila (no loop)")
	
	# Start first turn
	current_turn = 1
	current_character_index = 0
	print("[TurnBasedGameState] === Starting Demo Turn Sequence ===")
	_start_next_turn()

func _initialize_character_state(unit: Node) -> void:
	# Ensure soul is accessible
	if not unit.soul:
		await get_tree().process_frame
		if not unit.soul:
			push_error("Unit %s does not have soul component!" % unit.name)
			return
	
	var name = unit.soul.personality.name
	print("[TurnBasedGameState] Initializing character state for: %s" % name)
	
	# Initialize goals, knowledge, fear, composure
	if not unit.soul.has_method("initialize_turn_based_state"):
		push_error("Unit %s does not have initialize_turn_based_state method" % name)
		return
	
	var goal = character_goals.get(name, "No goal defined.")
	if goal == "No goal defined.":
		push_warning("No goal found for character: %s" % name)
	
	# Initial knowledge about the situation
	var initial_knowledge = [
		"Somchai has been murdered by a Neural Link overload in the penthouse",
		"You are all gathered in the penthouse where the murder occurred",
		"The Neural Link system that killed Somchai is still active and being investigated",
		"Each of you had access to Somchai and the Neural Link system",
		"An AI detective (UNIT-7) is investigating the murder",
		"Emotions were weaponized through the Neural Link system to manipulate behavior",
		"The scene is currently secured but evidence is still being collected"
	]
	
	unit.soul.initialize_turn_based_state(goal, initial_knowledge)

func _start_next_turn() -> void:
	# Loop continuously through all characters
	print("[TurnBasedGameState] _start_next_turn called: current_character_index=%d, turn_order.size()=%d" % [current_character_index, turn_order.size()])
	
	# If we've gone through all characters, loop back to the beginning
	if current_character_index >= turn_order.size():
		current_character_index = 0
		current_turn += 1
	# Check if demo sequence is complete
	if current_character_index >= turn_order.size():
		print("[TurnBasedGameState] === Demo Complete: All 4 characters acted once ===")
		return
	
	var character = turn_order[current_character_index]
	
	# Validate character exists
	if not is_instance_valid(character):
		push_error("[TurnBasedGameState] Invalid character at index %d - character is null or freed" % current_character_index)
		return
	
	# For player character, check if it's in Player group (soul might not be ready yet)
	var is_player = character.is_in_group("Player")
	
	# Wait for soul if not ready (especially for player)
	var character_name = "Unknown"
	if not character.soul:
		print("[TurnBasedGameState] Waiting for soul component for character at index %d..." % current_character_index)
		await get_tree().process_frame
		if not character.soul:
			# If still no soul, use fallback behavior
			if is_player:
				character_name = "Somchai (Ghost)"
				print("[TurnBasedGameState] Player turn but soul not initialized - using fallback name")
			else:
				push_error("[TurnBasedGameState] Invalid character at index %d - no soul component" % current_character_index)
				return
		else:
			character_name = character.soul.personality.name
	else:
		character_name = character.soul.personality.name
	
	print("[TurnBasedGameState] === Character %d/%d: %s's Action ===" % [current_character_index + 1, turn_order.size(), character_name])
	
	# Calculate turns until player's turn
	var turns_until_player = 0
	var found_player = false
	for i in range(current_character_index, turn_order.size()):
		var unit = turn_order[i]
		if unit.is_in_group("Player"):
			turns_until_player = i - current_character_index
			found_player = true
			break
	
	# Emit turn counter update
	emit_signal("turn_counter_updated", turns_until_player, character_name)
	
	# Check if this is Somchai (player) turn
	var is_player_turn = character.is_in_group("Player")
	var is_somchai = character_name == "Somchai"
	print("[TurnBasedGameState] Character is Somchai: %s, is_player_turn: %s" % [is_somchai, is_player_turn])
	
	# Don't clear bubbles here - wait until we're ready to show the next one
	# Bubbles will be cleared in _show_character_action() right before showing new content
	
	# Original check for index >= turn_order.size() is now handled at the beginning
	# if current_character_index >= turn_order.size():
	# 	print("[TurnBasedGameState] ERROR: current_character_index (%d) >= turn_order.size() (%d)!" % [current_character_index, turn_order.size()])
	# 	return
	
	# Original character validation is now handled above
	# if not character:
	# 	push_error("Character at index %d is null!" % current_character_index)
	# 	print("[TurnBasedGameState] Turn order contents:")
	# 	for i in range(turn_order.size()):
	# 		print("  [%d]: %s" % [i, turn_order[i] if turn_order[i] else "NULL"])
	# 	return
	# if not character.soul:
	# 	push_error("Character at index %d has no soul!" % current_character_index)
	# 	print("[TurnBasedGameState] Character at index %d: %s (has soul: %s)" % [current_character_index, character.name, "soul" in character])
	# 	return
	
	# CHECK IF IT'S PLAYER'S TURN - MULTIPLE WAYS
	# var is_player_turn = false # Already determined above
	# if character.is_in_group("Player"):
	# 	is_player_turn = true
	# 	print("[TurnBasedGameState] DETECTED PLAYER BY GROUP")
	# elif current_character_index == 2:  # Player is at index 2 in demo
	# 	is_player_turn = true
	# 	print("[TurnBasedGameState] DETECTED PLAYER BY INDEX 2")
	var char_name = character.soul.personality.name if (character.soul and character.soul.personality) else "Unknown"
	var turn_info = "Character %d/%d" % [current_character_index + 1, turn_order.size()]
	print("[TurnBasedGameState] === %s: %s's Action ===" % [turn_info, char_name])
	print("[TurnBasedGameState] Character is Somchai: %s, is_player_turn: %s" % [char_name == "Somchai", is_player_turn])
	
	is_processing_turn = true
	turn_started.emit(current_turn, character)
	
	# IF IT'S PLAYER'S TURN, SHOW UI DIRECTLY - NO SIGNALS NEEDED
	if is_player_turn:
		print("[TurnBasedGameState] PLAYER TURN DETECTED - SHOWING UI AFTER 2 SECOND DELAY")
		# Wait 2 seconds before showing UI
		await get_tree().create_timer(2.0).timeout
		# Try direct method first
		_show_player_input_ui_directly()
		# Also emit signal as backup
		print("[TurnBasedGameState] Also emitting ghost_action_requested signal as backup...")
		ghost_action_requested.emit()
		return
	
	# Prompt character to take action
	print("[TurnBasedGameState] Calling _process_character_turn for %s..." % char_name)
	_process_character_turn(character)
	print("[TurnBasedGameState] _process_character_turn completed for %s" % char_name)

func _show_player_input_ui_directly() -> void:
	print("[TurnBasedGameState] _show_player_input_ui_directly called - finding GhostActionInput UI...")
	
	# Find GhostActionInput UI directly
	var ghost_ui = get_node_or_null("/root/Game/GhostActionInput")
	if not ghost_ui:
		# Try finding it in the scene tree
		var game_node = get_node_or_null("/root/Game")
		if game_node:
			for child in game_node.get_children():
				if child.name == "GhostActionInput" or child.get_script() and child.get_script().resource_path.ends_with("GhostActionInput.gd"):
					ghost_ui = child
					break
	
	if ghost_ui:
		print("[TurnBasedGameState] Found GhostActionInput UI: %s" % ghost_ui.name)
		# Call the show method directly
		if ghost_ui.has_method("_show_input_panel"):
			print("[TurnBasedGameState] Calling _show_input_panel directly...")
			ghost_ui.call_deferred("_show_input_panel")
		elif ghost_ui.has_method("_on_ghost_action_requested"):
			print("[TurnBasedGameState] Calling _on_ghost_action_requested directly...")
			ghost_ui.call_deferred("_on_ghost_action_requested")
		else:
			# Try to access panel directly
			if "panel" in ghost_ui:
				var panel = ghost_ui.panel
				if panel:
					print("[TurnBasedGameState] Setting panel visible directly...")
					ghost_ui.visible = true
					panel.visible = true
					if "input_field" in ghost_ui and ghost_ui.input_field:
						ghost_ui.input_field.grab_focus()
	else:
		print("[TurnBasedGameState] ERROR: GhostActionInput UI not found!")
		# Emit signal as fallback
		print("[TurnBasedGameState] Emitting ghost_action_requested signal as fallback...")
		ghost_action_requested.emit()

func _clear_all_speech_bubbles() -> void:
	# Clear speech bubbles from all units
	var units = get_tree().get_nodes_in_group("Units")
	for unit in units:
		if unit.has_method("clear_speech_bubbles"):
			unit.clear_speech_bubbles()
		else:
			# Fallback: find and remove DialogueBubble children
			for child in unit.get_children():
				if child is DialogueBubble or child.name == "DialogueBubble":
					child.queue_free()

func _process_character_turn(character: Node) -> void:
	if not character.soul:
		push_error("Character has no soul component!")
		return
	
	var char_name = character.soul.personality.name if (character.soul and character.soul.personality) else "Unknown"
	print("[TurnBasedGameState] _process_character_turn called for: %s" % char_name)
	print("[TurnBasedGameState] Character node name: %s, in Player group: %s, current_character_index: %d" % [character.name, character.is_in_group("Player"), current_character_index])
	
	# Check if this is Somchai (Player) - multiple ways to detect
	var is_player = false
	
	# Method 1: Check by soul name
	if char_name == "Somchai":
		is_player = true
		print("[TurnBasedGameState] Detected player by soul name: Somchai")
	
	# Method 2: Check by Player group (most reliable)
	if not is_player and character.is_in_group("Player"):
		is_player = true
		print("[TurnBasedGameState] Detected player by Player group")
	
	# Method 3: Check by position in turn order (index 2 should be player in demo)
	if not is_player and current_character_index == 2:
		is_player = true
		print("[TurnBasedGameState] Detected player by turn order position (index 2)")
	
	# Method 4: Check if node name contains "Player"
	if not is_player and "Player" in character.name:
		is_player = true
		print("[TurnBasedGameState] Detected player by node name containing 'Player'")
	
	if is_player:
		print("[TurnBasedGameState] It's Somchai's turn - requesting player input")
		print("[TurnBasedGameState] Emitting ghost_action_requested signal...")
		print("[TurnBasedGameState] Signal connections: %d" % ghost_action_requested.get_connections().size())
		# Show the ghost action input UI for player's turn
		ghost_action_requested.emit()
		print("[TurnBasedGameState] ghost_action_requested signal emitted")
		return
	
	# For NPCs, use LLM to generate action
	# Get character's current state
	var state = character.soul.get_turn_based_state()
	
	# Build prompt for LLM
	var prompt = _build_turn_prompt(character, state)
	if prompt.is_empty():
		return
	
	# Request LLM to generate action
	GlobalSignalBus.request_turn_action.emit(character, prompt)

func _build_turn_prompt(character: Node, state: Dictionary) -> String:
	if not character.soul:
		push_error("Character has no soul!")
		return ""
	var name = character.soul.personality.name
	var goal = character_goals.get(name, "No goal defined.")
	var knowledge = state.get("knowledge", [])
	var fear = state.get("fear", 0.5)
	var composure = state.get("composure", 0.5)
	
	# Build knowledge summary
	var knowledge_text = ""
	if knowledge.size() > 0:
		knowledge_text = "\n\nCURRENT KNOWLEDGE:\n"
		for i in range(knowledge.size()):
			knowledge_text += "%d. %s\n" % [i + 1, knowledge[i]]
	else:
		knowledge_text = "\n\nCURRENT KNOWLEDGE: None yet."
	
	# Get what other characters know (for context)
	var other_characters_context = _get_other_characters_context(character)
	
	# Special instruction for Lila if player just acted
	var special_instruction = ""
	if name == "Lila" and current_character_index == 3:  # Lila is at index 3, player is at index 2
		# Get player's last action
		var player_action = ""
		for unit in turn_order:
			if unit.is_in_group("Player") or (unit.soul and unit.soul.personality and unit.soul.personality.name == "Somchai"):
				if unit.soul:
					var recent_actions = unit.soul.get_recent_actions()
					if recent_actions.size() > 0:
						var last_action = recent_actions[-1]
						player_action = last_action.get("text", "")
				break
		
		if player_action != "":
			special_instruction = "\n\nIMPORTANT: Somchai (the ghost/player) just acted. Their action was: \"%s\"\nYou should respond to what just happened. Consider how this affects you, your goals, and the investigation." % player_action
	
	return """You are %s in a murder mystery investigation.

YOUR GOAL: %s

CURRENT STATE:
- Fear: %.1f/1.0 (0.0 = calm, 1.0 = terrified)
- Composure: %.1f/1.0 (0.0 = breaking down, 1.0 = perfectly calm)
%s

OTHER CHARACTERS' RECENT ACTIONS:
%s%s

Generate what %s says or thinks in this turn. Consider:
1. Your goal and how to advance it
2. Your current knowledge and what you've learned
3. Your fear and composure levels (high fear = more panicked, low composure = more emotional)
4. What others have said/done

Output JSON ONLY:
{
	"action_type": "speech" or "thought" or "whisper",
	"target": "character_name" or null (if whisper or directed speech),
	"text": "What the character says/thinks",
	"visibility": "public" or "private" (public = everyone hears, private = only target hears, others see whispering),
	"state_changes": {
		"fear_delta": 0.0,
		"composure_delta": 0.0,
		"new_knowledge": ["new fact learned", "another fact"]
    },
	"knowledge_updates": {
		"UNIT-7": ["what UNIT-7 learns"],
		"Madam Vanna": ["what Vanna learns"],
		"Dr. Aris": ["what Aris learns"],
		"Lila": ["what Lila learns"]
    }
}
""" % [name, goal, fear, composure, knowledge_text, other_characters_context, special_instruction, name]

func _get_other_characters_context(character: Node) -> String:
	var context = ""
	for unit in turn_order:
		if unit == character:
			continue
		if not unit.soul:
			continue
		var name = unit.soul.personality.name
		var recent_actions = unit.soul.get_recent_actions()
		if recent_actions.size() > 0:
			context += "- %s: %s\n" % [name, recent_actions[-1].get("text", "No action yet")]
		else:
			context += "- %s: Hasn't acted yet\n" % name
	return context

func _end_round() -> void:
	# This function is no longer used - player turn is handled in _process_character_turn
	# when current_character_index points to Somchai
	pass

func submit_ghost_action(action_text: String, target_character: Node = null) -> void:
	var target_name = "None"
	if target_character and target_character.soul:
		target_name = target_character.soul.personality.name
	print("[TurnBasedGameState] Player (Somchai) action submitted: '%s' (target: %s)" % [action_text, target_name])
	
	# Record Somchai's action - find by Player group or by name
	var somchai = null
	for unit in turn_order:
		if unit.is_in_group("Player") or (unit.soul and unit.soul.personality and unit.soul.personality.name == "Somchai"):
			somchai = unit
			break
	if somchai and somchai.soul:
		somchai.soul.record_action({
			"type": "speech",
			"text": action_text,
			"target": target_name,
			"visibility": "public" if not target_character else "whisper"
		})
	
	# Broadcast ghost event to ALL characters
	var ghost_event_message = "A strange presence fills the air... It seems a ghost has haunted the area. " + action_text
	var ghost_context = "This may be the work of Somchai's ghost, who is still around trying to say something."
	
	print("[TurnBasedGameState] Broadcasting ghost event to all characters: %s" % ghost_event_message)
	
	# Notify all characters about the ghost event
	for unit in turn_order:
		if not unit.soul or unit == somchai:
			continue
		
		var unit_name = unit.soul.personality.name if unit.soul.personality else "Unknown"
		
		# Add ghost event to their knowledge
		var ghost_knowledge = ghost_event_message + " " + ghost_context
		unit.soul.add_knowledge(ghost_knowledge)
		
		# Decrease composure (sanity) - ghost events are unsettling
		var current_state = unit.soul.get_turn_based_state()
		var current_composure = current_state.get("composure", 0.5)
		var composure_delta = -0.15  # Decrease composure by 0.15
		unit.soul.apply_turn_state_changes({
			"composure_delta": composure_delta,
			"fear_delta": 0.1  # Slight increase in fear
		})
		
		# Record the ghost event as an observed action
		unit.soul.observe_action(somchai, "ghost_event", ghost_event_message, "observed")
		
		print("[TurnBasedGameState] Notified %s about ghost event. Composure decreased by %.2f" % [unit_name, abs(composure_delta)])
	
	# Apply ghost action to target character's knowledge (if specific target)
	if target_character and target_character.soul:
		target_character.soul.add_ghost_influence(action_text)
	
	is_ghost_turn = false
	
	# Player has acted - move to next character (which will be first NPC of next round)
	current_character_index += 1
	
	# Wait a moment before starting next turn
	await get_tree().create_timer(1.0).timeout
	_start_next_turn()

func on_character_action_completed(character: Node, action_result: Dictionary) -> void:
	# Character can be Unit or Player (both have soul component)
	if not ("soul" in character and character.soul):
		push_error("TurnBasedGameState: Character has no soul component: %s" % character)
		return
	
	var unit = character
	if not unit.soul:
		push_error("Unit has no soul component!")
		return
	
	# Apply state changes
	if "state_changes" in action_result:
		var changes = action_result["state_changes"]
		unit.soul.apply_turn_state_changes(changes)
	
	# Apply knowledge updates to all characters
	if "knowledge_updates" in action_result:
		var updates = action_result["knowledge_updates"]
		for u in turn_order:
			if not u.soul:
				continue
			var name = u.soul.personality.name
			if name in updates:
				for knowledge_item in updates[name]:
					u.soul.add_knowledge(knowledge_item)
	
	# Record action
	unit.soul.record_action(action_result)
	
	# Show action visually
	_show_character_action(unit, action_result)
	
	# Move to next character
	current_character_index += 1
	is_processing_turn = false
	turn_ended.emit(current_turn, unit)
	
	var char_name = unit.soul.personality.name if unit.soul else "Unknown"
	print("[TurnBasedGameState] %s's turn completed. Moving to next character..." % char_name)
	
	# Wait a bit before next turn
	await get_tree().create_timer(2.0).timeout
	_start_next_turn()

func _show_character_action(character: Node, action: Dictionary) -> void:
	# Clear this character's speech bubbles right before showing new content
	# This ensures previous bubbles stay visible until the next one is ready
	if character.has_method("clear_speech_bubbles"):
		character.clear_speech_bubbles()
	else:
		# Fallback: find and remove DialogueBubble children
		for child in character.get_children():
			if child is DialogueBubble or child.name == "DialogueBubble":
				child.queue_free()
	
	var action_type = action.get("action_type", "speech")
	var text = action.get("text", "...")
	var visibility = action.get("visibility", "public")
	var target_name = action.get("target", "")
	
	# Ensure target_name is never null (convert null to empty string)
	if target_name == null:
		target_name = ""
	
	# Show speech bubble or thought bubble
	if action_type == "thought":
		character.show_thought(text)
	elif action_type == "whisper" or visibility == "private":
		character.show_whisper(text, target_name)
	else:
		character.talk(text)
	
	# Notify other characters based on visibility
	_notify_action_visibility(character, action)

func _notify_action_visibility(actor: Node, action: Dictionary) -> void:
	var visibility = action.get("visibility", "public")
	var target_name = action.get("target", "")
	var action_type = action.get("action_type", "speech")
	var text = action.get("text", "")
	
	if visibility == "public":
		# Everyone hears it
		for unit in turn_order:
			if unit != actor and unit.soul:
				unit.soul.observe_action(actor, action_type, text, "heard")
	elif visibility == "private" or action_type == "whisper":
		# Only target hears it, others see whispering
		var target_unit = null
		for unit in turn_order:
			if unit.soul and unit.soul.personality.name == target_name:
				target_unit = unit
				break
		
		if target_unit and target_unit.soul:
			target_unit.soul.observe_action(actor, action_type, text, "heard")
		
		# Others see whispering but don't hear content
		var actor_name = actor.soul.personality.name if actor.soul else "Unknown"
		for unit in turn_order:
			if unit != actor and unit != target_unit and unit.soul:
				unit.soul.observe_action(actor, "whisper", "[%s whispers to %s]" % [actor_name, target_name], "observed")
