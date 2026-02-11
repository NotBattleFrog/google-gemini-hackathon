class_name SoulComponent
extends Node

# The unique psyche of a unit
var personality: Dictionary = {
	"name": "Unit",
	"archetype": "Soldier",
	"sex": "Male",  # Male or Female
	"traits": ["Weary", "Superstitious"], # Dynamic list
	"loyalty": 1.0,
	"morale": 1.0 # Affects stats
}

var memories: Array[String] = []  # Simple text log (legacy)
var relationship_summaries: Dictionary = {}
# Structure: {npc_name: {summary, last_updated, interaction_count}}

var cooldown_timer: Timer
var save_timer: Timer
var needs_save: bool = false

# Daily conversation limits
var daily_conversations: Dictionary = {}  # {partner_name: conversation_count}
var last_reset_day: int = 0
const MAX_PARTNERS_PER_DAY: int = 2
const MAX_CONVERSATIONS_PER_PARTNER: int = 3

const COOLDOWN_TIME: float = 15.0 # Seconds between chats
const CONVERSATIONS_DIR = "user://npc_conversations/"
const SAVE_DEBOUNCE_TIME: float = 5.0  # PERFORMANCE: Batch saves every 5 seconds (reduced I/O)

var unit_owner: Node = null  # Reference to the owning Unit

# Turn-Based State
var goal: String = ""
var knowledge: Array[String] = []
var fear: float = 0.5  # 0.0 = calm, 1.0 = terrified
var composure: float = 0.5  # 0.0 = breaking down, 1.0 = perfectly calm
var recent_actions: Array[Dictionary] = []  # Store recent actions for context
var ghost_influences: Array[String] = []  # Ghost whispers/influences

func _ready() -> void:
	add_to_group("souls")
	unit_owner = get_parent()
	if not unit_owner:
		push_error("SoulComponent must be child of a Unit")
	
	# Setup cooldown timer
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	add_child(cooldown_timer)
	
	# Setup save debounce timer
	save_timer = Timer.new()
	save_timer.wait_time = SAVE_DEBOUNCE_TIME
	save_timer.one_shot = false
	save_timer.timeout.connect(_do_batched_save)
	add_child(save_timer)
	save_timer.start()
		
	# Randomize initial personality for testing (only if name not already set)
	if personality.name == "Unit" or personality.name.is_empty():
		_randomize_persona()
	
	# Load persistent conversation summaries
	load_conversations()

func _randomize_persona() -> void:
	var archetypes = ["Veteran Knight", "Rookie Archer", "Grumpy Builder", "Optimistic Bard", "Female Merchant"]
	var all_traits = ["Brave", "Cowardly", "Greedy", "Honorable", "Drunk", "Pious", "Cynical", "Shrewd", "Charming"]
	var sexes = ["Male", "Female"]
	
	personality.archetype = archetypes.pick_random()
	personality.sex = sexes.pick_random()
	personality.traits = [all_traits.pick_random(), all_traits.pick_random()]
	personality.name = personality.archetype + " " + str(randi() % 100) # Unique ID

func can_socialize() -> bool:
	# Don't socialize during battle
	var battle_manager = get_node_or_null("/root/Game/BattleManager")
	if battle_manager and battle_manager.is_in_battle():
		return false
	# Cooldown removed - turn-based system handles timing
	return true

func initiate_social_interaction(other_soul: SoulComponent, extra_context: String = "") -> void:
	if not can_socialize() or not other_soul.can_socialize():
		return
	
	# Check daily conversation limits
	_check_daily_reset()
	var partner_name = other_soul.personality.name
	
	# Check if already hit max conversations with this partner today
	var conversations_with_partner = daily_conversations.get(partner_name, 0)
	if conversations_with_partner >= MAX_CONVERSATIONS_PER_PARTNER:
		print("[Soul] %s already had %d conversations with %s today" % [personality.name, MAX_CONVERSATIONS_PER_PARTNER, partner_name])
		return
	
	# Check if already at max unique partners and this is a new partner
	var unique_partners = daily_conversations.keys().size()
	if unique_partners >= MAX_PARTNERS_PER_DAY and not partner_name in daily_conversations:
		print("[Soul] %s already talked to %d different NPCs today. Can't talk to %s." % [personality.name, MAX_PARTNERS_PER_DAY, partner_name])
		return
	
	# Increment conversation count
	daily_conversations[partner_name] = conversations_with_partner + 1
	print("[Soul] %s conversation %d/%d with %s (unique partners today: %d/%d)" % [
		personality.name,
		daily_conversations[partner_name],
		MAX_CONVERSATIONS_PER_PARTNER,
		partner_name,
		unique_partners + (1 if conversations_with_partner == 0 else 0),
		MAX_PARTNERS_PER_DAY
	])
		
	# Cooldown removed - turn-based system handles timing
	# cooldown_timer.start(COOLDOWN_TIME)
	# other_soul.cooldown_timer.start(COOLDOWN_TIME)
	
	print("Soul %s initiating chat with %s" % [personality.name, other_soul.personality.name])
	
	# Construct the LLM Request
	var prompt = _construct_social_prompt(other_soul, extra_context)
	
	# In a real async system, we'd need a way to route the SPECIFIC response back to THIS soul.
	# For this prototype, we will use a global signal with an ID or just hijack the main service for a moment.
	# Let's assume we can pass a "context_id" or similar, but LLMStreamService is simple.
	# We will emit a signal that the Game controller or a SocialManager listens to.
	
	GlobalSignalBus.request_social_interaction.emit(self, other_soul, prompt)

func _construct_social_prompt(other: SoulComponent, extra_context: String = "") -> String:
	var my_desc = "%s (%s). Traits: %s. Recent Memory: %s" % [personality.name, personality.archetype, ", ".join(personality.traits), memories.back() if not memories.is_empty() else "None"]
	var their_desc = "%s (%s). Traits: %s." % [other.personality.name, other.personality.archetype, ", ".join(other.personality.traits)]
	
	# Add relationship summary context
	var my_relationship = relationship_summaries.get(other.personality.name, {}).get("summary", "")
	var their_relationship = other.relationship_summaries.get(personality.name, {}).get("summary", "")
	
	var my_context = ""
	if my_relationship:
		my_context = "\nRelationship history with %s: %s" % [other.personality.name, my_relationship]
	
	var their_context = ""
	if their_relationship:
		their_context = "\nRelationship history with %s: %s" % [personality.name, their_relationship]
	
	# Assuming 'their_rumors' is a variable that would be defined elsewhere or passed in.
	# For now, I'll define it as an empty array to make the code syntactically correct.
	var their_rumors: Array[String] = [] # Placeholder for their rumors
	var rumor_context = ""
	if not their_rumors.is_empty():
		rumor_context += "\n%s recently talked about: %s" % [other.personality.name, "; ".join(their_rumors)]
		
	# Add Ghost Message / Context Override
	# NEW CONTEXT: The Dynamic Duo Twist
	var final_context = "MURDER MYSTERY SIMULATION. Player is Somchai (Ghost). Detective is UNIT-7 (AI)."
	final_context += "\nSCENARIO: Somchai was murdered by a Neural Link overload. Suspects were emotionally manipulated."
	
	# INJECT DEEP MIND
	var my_role = personality.get("role", "Suspect")
	var my_secret = personality.get("secret", "")
	var my_conflict = personality.get("conflict", "")
	
	if not my_secret.is_empty():
		final_context += "\n\n[YOUR HIDDEN TRUTH]"
		final_context += "\nSECRET GOAL: %s" % my_secret
		final_context += "\nWEAPONIZED EMOTION: %s" % personality.get("state", "Neutral") # We stored emotion in 'state'
		final_context += "\nINNER CONFLICT: %s" % my_conflict
		
		# Context specific instructions
		if my_role == "Detective":
			final_context += "\nSPECIAL INSTRUCTION: You are an AI. You believe you are innocent, but you are actually the killer (Memory Erased). Focus on logic."
		else:
			final_context += "\nINSTRUCTION: You are driven by your Weaponized Emotion. Hide your Secret Goal. You suspect the others."
	
	if not extra_context.is_empty():
		final_context += "\n\n[GHOSTLY WHISPER]\n" + extra_context
	
	return """
	Generate a short 2-line dialogue between these two characters.
	Character A: %s%s
	Character B: %s%s
	Context: %s
	
	Output JSON ONLY:
	{
		"dialogue": [
			{"speaker": "A", "text": "..."},
			{"speaker": "B", "text": "..."}
		],
		"summary": "Brief 1-sentence summary of this conversation",
		"interaction_result": {
			"relationship_change": 0.1,
			"morale_impact_A": 0.1,
			"morale_impact_B": 0.0,
			"new_trait_A": "Inspired"
		}
	}
	""" % [my_desc, my_context, their_desc, their_context, final_context]

func apply_interaction_result(result: Dictionary, other_soul: SoulComponent) -> void:
	# Called by the manager when LLM returns JSON
	if "interaction_result" in result:
		var res = result["interaction_result"]
		
		# Apply Stats
		personality.morale = clamp(personality.morale + res.get("morale_impact_A", 0.0), 0.0, 1.0)
		other_soul.personality.morale = clamp(other_soul.personality.morale + res.get("morale_impact_B", 0.0), 0.0, 1.0)
		
		# Add Trait?
		if res.get("new_trait_A"):
			personality.traits.append(res["new_trait_A"])
			# Limit traits
			if personality.traits.size() > 5: personality.traits.pop_front()
			
		# Add Memory (legacy)
		var conversation = "Chatted with %s." % other_soul.personality.name
		memories.append(conversation)
		other_soul.memories.append("Chatted with %s." % personality.name)
		
	# Always update relationship summaries (whether interaction_result exists or not)
	if "dialogue" in result and "summary" in result:
		var new_summary = result.get("summary", "Had a conversation")
		update_relationship_summary(other_soul.personality.name, result["dialogue"], new_summary)
		other_soul.update_relationship_summary(personality.name, result["dialogue"], new_summary)
		
		# Notify nearby eavesdroppers
		if unit_owner and unit_owner.has_method("notify_eavesdroppers"):
			unit_owner.notify_eavesdroppers(other_soul.unit_owner, new_summary)
		
		# Show Bubble (Visuals)
	if "dialogue" in result:
		var dialogue = result["dialogue"]
		print("[Soul] Dialogue received: ", dialogue)
		# Execute Dialogue Sequence (needs a coroutine or timer in Unit)
		if unit_owner.has_method("play_dialogue_sequence"):
			print("[Soul] Calling play_dialogue_sequence on ", unit_owner.name)
			unit_owner.play_dialogue_sequence(dialogue, other_soul.unit_owner)
		else:
			print("[Soul] ERROR: unit_owner does not have play_dialogue_sequence method!")
	else:
		print("[Soul] WARNING: No dialogue key in result!")

# Cumulative Relationship Summary System
func update_relationship_summary(partner_name: String, dialogue: Array, new_dialogue_summary: String) -> void:
	var old_summary = relationship_summaries.get(partner_name, {}).get("summary", "")
	
	# If no previous summary, just use the new one
	if old_summary.is_empty():
		relationship_summaries[partner_name] = {
			"summary": new_dialogue_summary,
			"last_updated": Time.get_unix_time_from_system(),
			"interaction_count": 1
		}
		print("[Soul] %s started relationship with %s: %s" % [personality.name, partner_name, new_dialogue_summary])
		save_conversations()
		return
	
	# Otherwise, merge via LLM
	print("[Soul] %s merging summary with %s" % [personality.name, partner_name])
	
	# Format dialogue text
	var dialogue_text = ""
	for line in dialogue:
		dialogue_text += "- %s: %s\n" % [line.get("speaker", "?"), line.get("text", "")]
	
	var prompt = """
Previous relationship summary: "%s"
New conversation:
%s

Generate a brief 1-2 sentence cumulative summary combining the previous summary with this new conversation.
Output ONLY JSON: {"summary": "..."}
""" % [old_summary, dialogue_text]
	
	# Request LLM merge
	GlobalSignalBus.request_summary_merge.emit(self, partner_name, prompt)

func _on_summary_merged(partner_name: String, merged_summary: String) -> void:
	var existing = relationship_summaries.get(partner_name, {})
	relationship_summaries[partner_name] = {
		"summary": merged_summary,
		"last_updated": Time.get_unix_time_from_system(),
		"interaction_count": existing.get("interaction_count", 0) + 1
	}
	print("[Soul] %s updated summary for %s: %s" % [personality.name, partner_name, merged_summary])
	save_conversations()

# Persistence (Batched)
func save_conversations() -> void:
	# Mark dirty for batched save
	needs_save = true

func _do_batched_save() -> void:
	if not needs_save:
		return
	
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(CONVERSATIONS_DIR):
		DirAccess.make_dir_recursive_absolute(CONVERSATIONS_DIR)
	
	var file_path = CONVERSATIONS_DIR + "%s.json" % personality.name
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(relationship_summaries, "\t"))
		print("[Soul] Batched save to %s" % file_path)
		needs_save = false
	else:
		push_error("[Soul] Failed to save conversations for %s" % personality.name)

func load_conversations() -> void:
	var file_path = CONVERSATIONS_DIR + "%s.json" % personality.name
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				if typeof(json.data) == TYPE_DICTIONARY:
					relationship_summaries = json.data
					print("[Soul] Loaded %d relationship summaries for %s" % [relationship_summaries.size(), personality.name])
				else:
					push_error("[Soul] Invalid data format in %s" % file_path)
					relationship_summaries = {}
			else:
				push_error("[Soul] JSON parse error: %s" % json.get_error_message())
				relationship_summaries = {}

# Eavesdropping (simplified - just store summary directly)
func overhear_conversation(speaker_a: SoulComponent, speaker_b: SoulComponent, summary: String) -> void:
	var overheard = "%s and %s" % [speaker_a.personality.name, speaker_b.personality.name]
	print("[Soul] %s overheard: %s talking - %s" % [personality.name, overheard, summary])
	# Could store overheard summaries separately if desired

func _check_daily_reset() -> void:
	var current_day = 1
	if has_node("/root/Game"):
		var game = get_node("/root/Game")
		if "current_day" in game:
			current_day = game.current_day
	
	if current_day > last_reset_day:
		print("[Soul] ✨ New day! %s can talk again (Day %d)" % [personality.name, current_day])
		daily_conversations.clear()
		last_reset_day = current_day

# ========== TURN-BASED SYSTEM METHODS ==========

func initialize_turn_based_state(character_goal: String, initial_knowledge_array: Array = []) -> void:
	goal = character_goal
	knowledge.clear()
	
	# Add initial knowledge if provided
	if initial_knowledge_array.size() > 0:
		knowledge.append_array(initial_knowledge_array)
	
	fear = 0.5  # Start at neutral
	composure = 0.5  # Start at neutral
	recent_actions.clear()
	ghost_influences.clear()
	print("[Soul] %s initialized with goal: %s" % [personality.name, goal.left(50) + "..."])
	if knowledge.size() > 0:
		print("[Soul] %s initial knowledge: %d items" % [personality.name, knowledge.size()])

func get_turn_based_state() -> Dictionary:
	return {
		"goal": goal,
		"knowledge": knowledge.duplicate(),
		"fear": fear,
		"composure": composure,
		"name": personality.name
	}

func apply_turn_state_changes(changes: Dictionary) -> void:
	if "fear_delta" in changes:
		fear = clamp(fear + changes["fear_delta"], 0.0, 1.0)
		print("[Soul] %s fear changed to %.2f" % [personality.name, fear])
	
	if "composure_delta" in changes:
		composure = clamp(composure + changes["composure_delta"], 0.0, 1.0)
		print("[Soul] %s composure changed to %.2f" % [personality.name, composure])
	
	if "new_knowledge" in changes:
		for item in changes["new_knowledge"]:
			add_knowledge(item)

func add_knowledge(item: String) -> void:
	if not item in knowledge:
		knowledge.append(item)
		print("[Soul] %s learned: %s" % [personality.name, item])

func add_ghost_influence(text: String) -> void:
	ghost_influences.append(text)
	add_knowledge("[GHOST WHISPER] " + text)
	print("[Soul] %s received ghost influence: %s" % [personality.name, text])

func record_action(action: Dictionary) -> void:
	recent_actions.append(action)
	# Keep only last 5 actions
	if recent_actions.size() > 5:
		recent_actions.pop_front()

func get_recent_actions() -> Array[Dictionary]:
	return recent_actions.duplicate()

func observe_action(actor: Node, action_type: String, text: String, observation_type: String) -> void:
	# observation_type: "heard" (full content) or "observed" (just saw something happen)
	var observation = ""
	if observation_type == "heard":
		observation = "%s said: '%s'" % [actor.soul.personality.name, text]
		add_knowledge(observation)
	elif observation_type == "observed":
		observation = text  # e.g., "[Actor whispers to Target]"
		add_knowledge(observation)
	
	print("[Soul] %s observed: %s" % [personality.name, observation])
