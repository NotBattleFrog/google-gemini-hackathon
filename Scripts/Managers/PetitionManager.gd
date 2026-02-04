extends Node

# Manages NPC petitions and emergent quest generation

signal petition_generated(quest: Quest)
signal petition_queue_ready(petitions: Array)

var pending_petitions: Array[Quest] = []
var active_quests: Array[Quest] = []
var petition_cooldown: Dictionary = {}  # {npc_name: day_last_petitioned}
var sabotage_queue: Array[Dictionary] = []

const MAX_DAILY_PETITIONS: int = 3
const PETITION_COOLDOWN_DAYS: int = 3

func _ready() -> void:
	print("[PetitionManager] Initialized")
	
	# Connect to day change if available
	if GlobalSignalBus:
		GlobalSignalBus.connect("day_changed", _on_day_changed)

func _on_day_changed(day: int) -> void:
	if day % 1 == 0:  # Every morning
		generate_daily_petitions()
	
	# Execute scheduled sabotage
	_execute_sabotage_events()

func _execute_sabotage_events() -> void:
	for sabotage in sabotage_queue:
		print("[PetitionManager] SABOTAGE! %s performed %s" % [sabotage.perpetrator, sabotage.type])
		
		# Apply sabotage effects
		match sabotage.type:
			"gate_unlock":
				GameStateTracker.log_event("SABOTAGE", "%s unlocked the gate!" % sabotage.perpetrator, 5)
			"supply_theft":
				GameStateTracker.log_event("SABOTAGE", "%s stole supplies!" % sabotage.perpetrator, 3)
				if EconomyManager:
					EconomyManager.modify_gold(-50)
			"wall_weaken":
				GameStateTracker.log_wall_breach("Sabotaged Section", 2)
	
	sabotage_queue.clear()

func generate_daily_petitions() -> void:
	print("[PetitionManager] ===== GENERATE_DAILY_PETITIONS CALLED =====")
	print("[PetitionManager] Generating daily petitions...")
	
	pending_petitions.clear() # Clear pending petitions from previous day
	
	# Get all souls
	var souls = get_tree().get_nodes_in_group("souls")
	print("[PetitionManager] Found %d souls in scene" % souls.size())
	
	if souls.size() == 0:
		print("[PetitionManager] WARNING: No souls found! Cannot generate petitions.")
		return
	
	# Get recent events
	var events = GameStateTracker.get_recent_events(5)
	if events.is_empty():
		print("[PetitionManager] No recent events. Generating generic petition.")
		_generate_generic_petition()
		return
	
	# Select eligible NPCs (not on cooldown)
	var eligible_npcs = []
	var current_day = get_current_day()
	print("[PetitionManager] Current day: %d" % current_day)
	
	for soul in souls:
		var npc_name = soul.personality.name
		var last_petition_day = petition_cooldown.get(npc_name, -999)  # Default to far past so eligible immediately
		var cooldown_remaining = PETITION_COOLDOWN_DAYS - (current_day - last_petition_day)
		
		if current_day - last_petition_day >= PETITION_COOLDOWN_DAYS:
			eligible_npcs.append(soul)
			print("[PetitionManager]   ✓ %s is eligible (last petition: day %d)" % [npc_name, last_petition_day])
		else:
			print("[PetitionManager]   ✗ %s on cooldown (%d days remaining, last petition: day %d)" % [npc_name, cooldown_remaining, last_petition_day])
	
	print("[PetitionManager] Eligible NPCs: %d / %d" % [eligible_npcs.size(), souls.size()])
	
	if eligible_npcs.size() == 0:
		print("[PetitionManager] No eligible NPCs for petitions.")
		return
	
	# Select 1-3 petitioners
	# The original code used `min(MAX_DAILY_PETITIONS, eligible_npcs.size())`
	# The new code uses `min(randi() % MAX_DAILY_PETITIONS + 1, eligible_npcs.size())`
	# I will use the new code's logic for randomizing petition count.
	var petition_count = min(randi() % MAX_DAILY_PETITIONS + 1, eligible_npcs.size())
	print("[PetitionManager] Generating %d petitions" % petition_count)
	
	for i in range(petition_count):
		var petitioner = eligible_npcs.pick_random()
		eligible_npcs.erase(petitioner)
		
		print("[PetitionManager] Selected petitioner: %s" % petitioner.personality.name)
		
		# Construct prompt
		var prompt = _construct_petition_prompt(petitioner, events) # Pass events to prompt construction
		print("[PetitionManager] Prompt length: %d characters" % prompt.length())
		
		# Request LLM generation
		print("[PetitionManager] Emitting request_petition_generation signal...")
		if GlobalSignalBus:
			GlobalSignalBus.request_petition_generation.emit(petitioner, prompt)
			print("[PetitionManager] Signal emitted successfully")
		else:
			print("[PetitionManager] ERROR: GlobalSignalBus not available!")
		
		# Mark cooldown (this was originally done in on_petition_received, moving it here for immediate cooldown)
		petition_cooldown[petitioner.personality.name] = current_day

func get_current_day() -> int:
	return GameStateTracker.get_current_day()

# This function is no longer used by the new generate_daily_petitions, but keeping it for completeness if other parts of the code still call it.
func _get_eligible_npcs() -> Array:
	var eligible = []
	var current_day = GameStateTracker.get_current_day()
	
	var souls = get_tree().get_nodes_in_group("souls")
	for soul in souls:
		var npc_name = soul.personality.name
		var last_petition = petition_cooldown.get(npc_name, 0)
		
		if current_day - last_petition >= PETITION_COOLDOWN_DAYS:
			eligible.append(soul)
	
	return eligible

func _construct_petition_prompt(npc_soul: Node, events: Array) -> String:
	# Build context for LLM
	var events_summary = ""
	for event in events:
		events_summary += "- %s: %s (Severity: %d)\n" % [event.type, event.description, event.severity]
	
	var prompt = """Game State Summary:
Recent Events:
%s

NPC Information:
- Name: %s
- Archetype: %s
- Sex: %s
- Morale: %.0f%%
- Loyalty: %.0f%%
- Traits: %s

Generate a petition from this NPC based on recent events. The NPC should request help or make demands.

Output JSON ONLY:
{
  "petition_text": "Your Majesty, [detailed petition explaining the problem and request]",
  "demand": "BUILD or DEFEND or GATHER or RECRUIT",
  "target": "[specific target like 'Windmill' or '100 Gold']",
  "location": "[location if applicable]",
  "reward_influence": [5-20],
  "penalty_mutiny": [3-15],
  "urgency": "LOW or MEDIUM or HIGH or CRITICAL"
}""" % [
		events_summary,
		npc_soul.personality.name,
		npc_soul.personality.archetype,
		npc_soul.personality.get("sex", "Unknown"),
		npc_soul.personality.morale * 100,
		npc_soul.personality.loyalty * 100,
		", ".join(npc_soul.personality.traits)
	]
	
	return prompt

func _request_petition_from_llm(npc_soul: Node, events: Array) -> void:
	# Build context for LLM
	var events_summary = ""
	for event in events:
		events_summary += "- %s: %s (Severity: %d)\n" % [event.type, event.description, event.severity]
	
	var prompt = """Game State Summary:
Recent Events:
%s

NPC Information:
- Name: %s
- Archetype: %s
- Sex: %s
- Morale: %.0f%%
- Loyalty: %.0f%%
- Traits: %s

Generate a petition from this NPC based on recent events. The NPC should request help or make demands.

Output JSON ONLY:
{
  "petition_text": "Your Majesty, [detailed petition explaining the problem and request]",
  "demand": "BUILD or DEFEND or GATHER or RECRUIT",
  "target": "[specific target like 'Windmill' or '100 Gold']",
  "location": "[location if applicable]",
  "reward_influence": [5-20],
  "penalty_mutiny": [3-15],
  "urgency": "LOW or MEDIUM or HIGH or CRITICAL"
}""" % [
		events_summary,
		npc_soul.personality.name,
		npc_soul.personality.archetype,
		npc_soul.personality.get("sex", "Unknown"),
		npc_soul.personality.morale * 100,
		npc_soul.personality.loyalty * 100,
		", ".join(npc_soul.personality.traits)
	]
	
	# Request from LLM
	GlobalSignalBus.request_petition_generation.emit(npc_soul, prompt)

func on_petition_received(npc_soul: Node, response: Dictionary) -> void:
	# Parse LLM response into Quest
	var quest_data = {
		"petitioner_name": npc_soul.personality.name,
		"petition_text": response.get("petition_text", "I petition for aid."),
		"quest_type": _parse_quest_type(response.get("demand", "BUILD")),
		"target": response.get("target", "Unknown"),
		"location": response.get("location", ""),
		"reward_influence": response.get("reward_influence", 10),
		"penalty_mutiny": response.get("penalty_mutiny", 5),
		"urgency": response.get("urgency", "MEDIUM"),
		"expiration_day": GameStateTracker.get_current_day() + 5
	}
	
	var quest = Quest.new(quest_data)
	pending_petitions.append(quest)
	
	petition_cooldown[npc_soul.personality.name] = GameStateTracker.get_current_day()
	
	print("[PetitionManager] Petition generated from %s" % npc_soul.personality.name)
	petition_generated.emit(quest)
	
	# If all petitions ready, emit queue
	if pending_petitions.size() >= 1:
		petition_queue_ready.emit(pending_petitions)

func _generate_generic_petition() -> void:
	# Fallback if no events
	var generic_quest = Quest.new({
		"petitioner_name": "Concerned Citizen",
		"petition_text": "Your Majesty, we humbly request additional resources to strengthen our defenses.",
		"quest_type": Quest.QuestType.GATHER,
		"target": "50 Gold",
		"location": "",
		"reward_influence": 5,
		"penalty_mutiny": 2,
		"urgency": "LOW"
	})
	
	pending_petitions.append(generic_quest)
	petition_queue_ready.emit(pending_petitions)

func _parse_quest_type(demand: String) -> Quest.QuestType:
	match demand.to_upper():
		"BUILD": return Quest.QuestType.BUILD
		"DEFEND": return Quest.QuestType.DEFEND
		"GATHER": return Quest.QuestType.GATHER
		"RECRUIT": return Quest.QuestType.RECRUIT
		"EXILE": return Quest.QuestType.EXILE
		"INVESTIGATE": return Quest.QuestType.INVESTIGATE
		_: return Quest.QuestType.BUILD

func accept_petition(quest: Quest) -> void:
	quest.accept()
	active_quests.append(quest)
	pending_petitions.erase(quest)
	
	# Apply rewards
	print("[PetitionManager] Quest accepted: %s - Influence +%d" % [quest.target, quest.reward_influence])
	
	# Increase petitioner loyalty
	var souls = get_tree().get_nodes_in_group("souls")
	for soul in souls:
		if soul.personality.name == quest.petitioner_name:
			soul.personality.loyalty = min(1.0, soul.personality.loyalty + 0.2)
			soul.personality.morale = min(1.0, soul.personality.morale + 0.1)
			print("[PetitionManager] %s loyalty increased to %.0f%%" % [quest.petitioner_name, soul.personality.loyalty * 100])
			break
	
	# TODO: Create quest marker at location

func reject_petition(quest: Quest) -> void:
	quest.reject()
	pending_petitions.erase(quest)
	
	# Apply penalties
	print("[PetitionManager] Quest rejected: %s - Mutiny +%d" % [quest.target, quest.penalty_mutiny])
	
	# Apply loyalty drop to petitioner
	var souls = get_tree().get_nodes_in_group("souls")
	for soul in souls:
		if soul.personality.name == quest.petitioner_name:
			soul.personality.loyalty -= quest.penalty_loyalty
			print("[PetitionManager] %s loyalty dropped to %.0f%%" % [quest.petitioner_name, soul.personality.loyalty * 100])
			
			# Schedule sabotage if loyalty too low
			if soul.personality.loyalty < 0.3:
				_schedule_sabotage(soul, quest)
			break

func _schedule_sabotage(npc_soul: Node, quest: Quest) -> void:
	# Chance of sabotage based on loyalty (lower = higher chance)
	var sabotage_chance = (1.0 - npc_soul.personality.loyalty) * 0.8  # 0-80%
	
	if randf() < sabotage_chance:
		var sabotage_types = ["gate_unlock", "supply_theft", "wall_weaken"]
		var sabotage_event = {
			"perpetrator": npc_soul.personality.name,
			"type": sabotage_types.pick_random(),
			"quest_type": Quest.QuestType.keys()[quest.quest_type]
		}
		
		sabotage_queue.append(sabotage_event)
		print("[PetitionManager] SABOTAGE SCHEDULED: %s will %s next night!" % [
			sabotage_event.perpetrator,
			sabotage_event.type
		])
