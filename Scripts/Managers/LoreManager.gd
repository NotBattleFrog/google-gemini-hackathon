extends Node

# The Chronicle: A log of major events that persists across runs.
enum EventType { BATTLE, DEATH, DIPLOMACY, TRADE, MUTINY, WAVE_COMPLETE, CASTLE_DAMAGE }

# Structured event tracking
var events: Array[Dictionary] = []  # {type, text, metadata, timestamp}
var east_reputation: float = 0.0    # -1.0 to 1.0
var west_reputation: float = 0.0

# Legacy data paths
const LEGACY_PATH = "user://legacy.save"
const CHRONICLES_PATH = "user://chronicles.json"

# Current run data
var current_run_id: String = ""
var waves_survived: int = 0
var tributes_paid: int = 0
var units_lost: int = 0

func _ready() -> void:
	current_run_id = "run_%d" % Time.get_unix_time_from_system()
	load_legacy()

func add_event(event_description: String, type: EventType = EventType.BATTLE, metadata: Dictionary = {}) -> void:
	var timestamp = Time.get_datetime_string_from_system()
	var entry = {
		"type": EventType.keys()[type],
		"text": event_description,
		"metadata": metadata,
		"timestamp": timestamp
	}
	events.append(entry)
	print("[Lore] Event Added: [%s] %s" % [entry.type, entry.text])
	
	# Update stats based on event type
	match type:
		EventType.WAVE_COMPLETE:
			waves_survived += 1
		EventType.TRADE:
			tributes_paid += 1
		EventType.DEATH:
			units_lost += 1

func modify_reputation(faction: String, amount: float) -> void:
	if faction == "EAST":
		east_reputation = clamp(east_reputation + amount, -1.0, 1.0)
	elif faction == "WEST":
		west_reputation = clamp(west_reputation + amount, -1.0, 1.0)
	print("[Lore] Reputation changed: %s %+.2f -> %.2f" % [faction, amount, east_reputation if faction == "EAST" else west_reputation])

func save_legacy() -> void:
	var file = FileAccess.open(LEGACY_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"events": events,
			"east_reputation": east_reputation,
			"west_reputation": west_reputation
		}
		file.store_var(data)

func load_legacy() -> void:
	if FileAccess.file_exists(LEGACY_PATH):
		var file = FileAccess.open(LEGACY_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			events = data.get("events", [])
			east_reputation = data.get("east_reputation", 0.0)
			west_reputation = data.get("west_reputation", 0.0)
	else:
		events = []

func get_lore_summary() -> String:
	if events.is_empty():
		return "The history books are empty."
	
	# Return last 10 events
	var recent = events.slice(-10)
	var lines: Array[String] = []
	for event in recent:
		lines.append("[%s] %s" % [event.type, event.text])
	return "\n".join(lines)

# Chronicle generation (LLM-based)
func generate_chronicle(outcome: String) -> void:
	print("[Lore] Generating chronicle for run: %s" % current_run_id)
	
	# Build event summary for LLM prompt
	var event_summary = ""
	for event in events:
		event_summary += "- %s: %s\n" % [event.type, event.text]
	
	var prompt = """
You are the Royal Historian of a medieval kingdom. Compile these events into a legendary chronicle.

Events:
%s

Outcome: %s
Waves Survived: %d
East Reputation: %.1f
West Reputation: %.1f

Generate a response in JSON format:
{
	"ruler_title": "The [Title]" (e.g., "The Brave", "The Miser", based on actions),
	"narrative": "A 3-paragraph epic tale of this ruler's reign"
}
""" % [event_summary, outcome, waves_survived, east_reputation, west_reputation]
	
	# Request LLM generation
	GlobalSignalBus.request_chronicle_generation.connect(_on_chronicle_generated)
	LLMController.generate_chronicle_text(prompt)

func _on_chronicle_generated(response: Dictionary) -> void:
	save_chronicle(response.get("narrative", "..."), response.get("ruler_title", "The Forgotten"))

func save_chronicle(narrative: String, ruler_title: String) -> void:
	var chronicles = load_chronicles()
	
	var new_chronicle = {
		"id": current_run_id,
		"date": Time.get_datetime_string_from_system(),
		"ruler_title": ruler_title,
		"narrative": narrative,
		"final_reputation": {"east": east_reputation, "west": west_reputation},
		"key_stats": {
			"waves_survived": waves_survived,
			"tributes_paid": tributes_paid,
			"units_lost": units_lost
		}
	}
	
	chronicles.append(new_chronicle)
	
	# Save to JSON
	var file = FileAccess.open(CHRONICLES_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(chronicles, "\t"))
		print("[Lore] Chronicle saved: %s" % ruler_title)

func load_chronicles() -> Array:
	if FileAccess.file_exists(CHRONICLES_PATH):
		var file = FileAccess.open(CHRONICLES_PATH, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_string()) == OK:
				return json.data
	return []

func get_latest_chronicle() -> Dictionary:
	var chronicles = load_chronicles()
	if chronicles.is_empty():
		return {}
	return chronicles[-1]
