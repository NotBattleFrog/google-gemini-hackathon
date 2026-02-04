extends CanvasLayer

# Petition UI - Shows NPC petitions and allows accept/reject

var current_petition: Quest = null
var petition_queue: Array[Quest] = []

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect to petition manager
	if PetitionManager:
		PetitionManager.petition_queue_ready.connect(_on_petition_queue_ready)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event.is_action_pressed("ui_accept"):
		_accept_petition()
	elif event.is_action_pressed("ui_cancel"):
		_reject_petition()

func _on_petition_queue_ready(petitions: Array) -> void:
	petition_queue = petitions
	if petition_queue.size() > 0:
		show_next_petition()

func show_next_petition() -> void:
	if petition_queue.is_empty():
		visible = false
		get_tree().paused = false
		return
	
	current_petition = petition_queue.pop_front()
	_display_petition(current_petition)
	visible = true
	get_tree().paused = true

func _display_petition(quest: Quest) -> void:
	# Update UI elements
	$Panel/VBox/Header/PetitionerName.text = "Petition from: %s" % quest.petitioner_name
	$Panel/VBox/PetitionText/Scroll/Text.text = quest.petition_text
	
	# Quest details
	var quest_type_str = Quest.QuestType.keys()[quest.quest_type]
	$Panel/VBox/QuestDetails/Type.text = "Type: %s" % quest_type_str
	$Panel/VBox/QuestDetails/Target.text = "Target: %s" % quest.target
	$Panel/VBox/QuestDetails/Location.text = "Location: %s" % quest.location if quest.location else "Location: N/A"
	$Panel/VBox/QuestDetails/Urgency.text = "Urgency: %s" % quest.urgency
	
	# Rewards/Penalties
	$Panel/VBox/Consequences/Rewards.text = "If Accepted:\n  +%d Influence" % quest.reward_influence
	if quest.reward_gold > 0:
		$Panel/VBox/Consequences/Rewards.text += "\n  +%d Gold" % quest.reward_gold
	
	$Panel/VBox/Consequences/Penalties.text = "If Rejected:\n  +%d Mutiny Risk\n  -%d%% Loyalty (%s)" % [
		quest.penalty_mutiny,
		int(quest.penalty_loyalty * 100),
		quest.petitioner_name
	]

func _accept_petition() -> void:
	if not current_petition:
		return
	
	print("[PetitionPanel] Accepting petition from %s" % current_petition.petitioner_name)
	
	if PetitionManager:
		PetitionManager.accept_petition(current_petition)
	
	GlobalSignalBus.petition_accepted.emit(current_petition)
	
	current_petition = null
	show_next_petition()

func _reject_petition() -> void:
	if not current_petition:
		return
	
	print("[PetitionPanel] Rejecting petition from %s" % current_petition.petitioner_name)
	
	if PetitionManager:
		PetitionManager.reject_petition(current_petition)
	
	GlobalSignalBus.petition_rejected.emit(current_petition)
	
	current_petition = null
	show_next_petition()
