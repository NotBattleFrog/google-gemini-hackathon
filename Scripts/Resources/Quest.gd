class_name Quest
extends Resource

# Emergent quest generated from NPC petitions

enum QuestType { BUILD, DEFEND, GATHER, RECRUIT, EXILE, INVESTIGATE }
enum QuestStatus { PENDING, ACTIVE, COMPLETED, FAILED, REJECTED }

@export var quest_id: String
@export var petitioner_name: String
@export var petition_text: String
@export var quest_type: QuestType
@export var target: String  # Building name, enemy type, resource, etc.
@export var location: String
@export var reward_influence: int = 0
@export var reward_gold: int = 0
@export var penalty_mutiny: int = 0
@export var penalty_loyalty: float = 0.0
@export var urgency: String = "MEDIUM"  # LOW, MEDIUM, HIGH, CRITICAL
@export var expiration_day: int = 0
@export var status: QuestStatus = QuestStatus.PENDING

func _init(data: Dictionary = {}):
	quest_id = data.get("quest_id", "quest_" + str(randi()))
	petitioner_name = data.get("petitioner_name", "Unknown")
	petition_text = data.get("petition_text", "")
	quest_type = data.get("quest_type", QuestType.BUILD)
	target = data.get("target", "")
	location = data.get("location", "")
	reward_influence = data.get("reward_influence", 10)
	reward_gold = data.get("reward_gold", 0)
	penalty_mutiny = data.get("penalty_mutiny", 5)
	penalty_loyalty = data.get("penalty_loyalty", 0.2)
	urgency = data.get("urgency", "MEDIUM")
	expiration_day = data.get("expiration_day", 0)

func accept() -> void:
	status = QuestStatus.ACTIVE
	print("[Quest] %s accepted quest: %s" % [petitioner_name, target])

func reject() -> void:
	status = QuestStatus.REJECTED
	print("[Quest] %s's petition rejected. Consequences incoming..." % petitioner_name)

func complete() -> void:
	status = QuestStatus.COMPLETED
	print("[Quest] Quest completed: %s" % target)

func fail() -> void:
	status = QuestStatus.FAILED
	print("[Quest] Quest failed: %s" % target)
