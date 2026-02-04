extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var input_field: LineEdit = $Panel/VBoxContainer/MessageInput
@onready var suspect_buttons_container: HBoxContainer = $Panel/VBoxContainer/SuspectContainer
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel

var mystery_manager: Node
var selected_suspect_index: int = -1

func _ready() -> void:
	$Panel.hide()
	$QueueContainer.show()
	
	# Wait for manager
	await get_tree().process_frame
	mystery_manager = get_tree().root.find_child("MysteryManager", true, false)
	if mystery_manager:
		mystery_manager.ghost_turn_started.connect(_on_ghost_turn_started)
		mystery_manager.ghost_turn_ended.connect(_on_ghost_turn_ended)
		mystery_manager.queue_updated.connect(_update_queue_display) 
		mystery_manager.progress_updated.connect(_update_progress)
		print("[GhostUI] Connected to MysteryManager")

func _update_progress(turns_left: int) -> void:
	if $QueueContainer/VBoxContainer/CountdownLabel:
		$QueueContainer/VBoxContainer/CountdownLabel.text = "Influence Ready In: %d" % turns_left

func _update_queue_display(queue_list: Array) -> void:
	var display_text = ""
	for i in range(min(queue_list.size(), 5)): # Show top 5
		var pair = queue_list[i]
		display_text += "%d. %s ↔ %s\n" % [i+1, pair[0].name, pair[1].name]
	
	if $QueueContainer/VBoxContainer/QueueListLabel:
		$QueueContainer/VBoxContainer/QueueListLabel.text = display_text

func _on_ghost_turn_started() -> void:
	$Panel.show()
	input_field.text = ""
	input_field.grab_focus()
	status_label.text = "Select a Suspect to Influence..."
	_create_suspect_buttons()

func _on_ghost_turn_ended() -> void:
	$Panel.hide()

func _create_suspect_buttons() -> void:
	# Clear old buttons
	for child in suspect_buttons_container.get_children():
		child.queue_free()
	
	if not mystery_manager: return
	
	# Create button for each suspect
	var suspects = mystery_manager.suspects
	for i in range(suspects.size()):
		var btn = Button.new()
		var suspect = suspects[i]
		btn.text = suspect.name # "Suspect N"
		btn.toggle_mode = true
		btn.button_group = load("res://Resources/SuspectButtonGroup.tres") # Optional, or just manual management
		btn.pressed.connect(_on_suspect_selected.bind(i))
		suspect_buttons_container.add_child(btn)

func _on_suspect_selected(index: int) -> void:
	selected_suspect_index = index
	status_label.text = "Type words for Suspect %d to say..." % (index + 1)

func _on_submit_pressed() -> void:
	var message = input_field.text.strip_edges()
	if message.is_empty():
		status_label.text = "You must whisper something..."
		return
	
	if selected_suspect_index == -1:
		status_label.text = "Select a vessel first!"
		return
		
	# Submit to Manager
	mystery_manager.submit_ghost_action(selected_suspect_index, message)
