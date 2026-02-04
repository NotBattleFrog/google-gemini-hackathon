extends Node

# Tracks game events that can trigger NPC petitions

signal event_logged(event: Dictionary)

var recent_events: Array[Dictionary] = []
const MAX_EVENTS: int = 20

func _ready() -> void:
	print("[GameStateTracker] Initialized")

# Event logging
func log_event(type: String, description: String, severity: int = 1, affected_npcs: Array = []) -> void:
	var event = {
		"type": type,
		"description": description,
		"severity": severity,  # 1-5 scale
		"affected_npcs": affected_npcs,
		"timestamp": Time.get_unix_time_from_system(),
		"day": get_current_day()
	}
	
	recent_events.append(event)
	print("[GameStateTracker] Event logged: %s - %s" % [type, description])
	
	# Prune old events
	if recent_events.size() > MAX_EVENTS:
		recent_events.pop_front()
	
	event_logged.emit(event)

# Specific event types
func log_wall_breach(location: String, severity: int = 3) -> void:
	log_event("WALL_BREACH", "The %s wall was breached by enemies" % location, severity)

func log_npc_death(npc_name: String, cause: String = "battle") -> void:
	log_event("NPC_DEATH", "%s died in %s" % [npc_name, cause], 4, [npc_name])

func log_resource_shortage(resource: String, amount: int) -> void:
	log_event("RESOURCE_SHORTAGE", "Low %s supply (only %d remaining)" % [resource, amount], 3)

func log_failed_defense(wave: int, casualties: int) -> void:
	log_event("FAILED_DEFENSE", "Wave %d overwhelmed defenses. %d casualties" % [wave, casualties], 5)

func log_morale_drop(npc_name: String, new_morale: float) -> void:
	if new_morale < 0.3:
		log_event("LOW_MORALE", "%s's morale critically low (%.0f%%)" % [npc_name, new_morale * 100], 2, [npc_name])

func log_building_destroyed(building: String, location: String) -> void:
	log_event("BUILDING_DESTROYED", "%s at %s was destroyed" % [building, location], 4)

# Query events
func get_recent_events(max_count: int = 10) -> Array[Dictionary]:
	var count = min(max_count, recent_events.size())
	return recent_events.slice(recent_events.size() - count, recent_events.size())

func get_events_by_type(type: String) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for event in recent_events:
		if event.type == type:
			filtered.append(event)
	return filtered

func get_events_affecting_npc(npc_name: String) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for event in recent_events:
		if npc_name in event.affected_npcs:
			filtered.append(event)
	return filtered

func get_current_day() -> int:
	# Hook into game time system if available
	if has_node("/root/Game"):
		var game = get_node("/root/Game")
		if "current_day" in game:
			return game.current_day
	return 1

func clear_events() -> void:
	recent_events.clear()
	print("[GameStateTracker] All events cleared")
