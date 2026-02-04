extends CanvasLayer

# Journal UI - Shows NPC conversation history

var is_open: bool = false
var selected_npc_index: int = 0
var npc_data: Array = []

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_journal"):
		toggle_journal()
	
	if not is_open:
		return
	
	# Navigation
	if event.is_action_pressed("ui_down"):
		selected_npc_index = min(selected_npc_index + 1, npc_data.size() - 1)
		_update_selection()
	elif event.is_action_pressed("ui_up"):
		selected_npc_index = max(selected_npc_index - 1, 0)
		_update_selection()
	elif event.is_action_pressed("ui_accept"):
		_show_npc_details()

func toggle_journal() -> void:
	is_open = not is_open
	visible = is_open
	
	if is_open:
		_load_npc_data()
		_populate_npc_list()
		get_tree().paused = true
	else:
		get_tree().paused = false

func _load_npc_data() -> void:
	npc_data.clear()
	
	# Get all Soul components from scene (show all NPCs, even without conversations)
	var souls = get_tree().get_nodes_in_group("souls")
	for soul in souls:
		npc_data.append({
			"name": soul.personality.name,
			"archetype": soul.personality.archetype,
			"sex": soul.personality.get("sex", "Unknown"),
			"traits": soul.personality.traits,
			"morale": soul.personality.morale,
			"loyalty": soul.personality.loyalty,
			"conversations": soul.relationship_summaries
		})

func _populate_npc_list() -> void:
	var list_container = $Panel/VBox/HBox/NPCListScroll/NPCList
	if not list_container:
		push_error("[Journal] NPCList node not found!")
		return
	
	# Clear existing
	for child in list_container.get_children():
		child.queue_free()
	
	# Add NPC entries
	for i in range(npc_data.size()):
		var npc = npc_data[i]
		var button = Button.new()
		button.text = "%s (%s)" % [npc.name, npc.archetype]
		button.pressed.connect(_on_npc_selected.bind(i))
		list_container.add_child(button)
	
	if npc_data.size() > 0:
		_update_selection()

func _on_npc_selected(index: int) -> void:
	selected_npc_index = index
	_show_npc_details()

func _update_selection() -> void:
	var list_container = $Panel/VBox/HBox/NPCListScroll/NPCList
	if not list_container:
		return
		
	for i in range(list_container.get_child_count()):
		var button = list_container.get_child(i)
		if i == selected_npc_index:
			button.modulate = Color(1.2, 1.2, 0.8)  # Highlight
		else:
			button.modulate = Color.WHITE

func _show_npc_details() -> void:
	if selected_npc_index >= npc_data.size():
		return
	
	var npc = npc_data[selected_npc_index]
	
	# Check nodes exist
	var name_label = $Panel/VBox/HBox/DetailPanel/NPCName
	var stats_label = $Panel/VBox/HBox/DetailPanel/Stats
	var conv_label = $Panel/VBox/HBox/DetailPanel/ConversationsScroll/Conversations
	
	if not name_label or not stats_label or not conv_label:
		push_error("[Journal] Detail panel nodes not found!")
		return
	
	# Update detail panel
	name_label.text = npc.name
	stats_label.text = """Archetype: %s
Sex: %s
Traits: %s
Morale: %.0f%%
Loyalty: %.0f%%""" % [
		npc.archetype,
		npc.sex,
		", ".join(npc.traits),
		npc.morale * 100,
		npc.loyalty * 100
	]
	
	# Show conversations
	var conv_text = ""
	for partner_name in npc.conversations:
		var conv = npc.conversations[partner_name]
		conv_text += "\n[b]With %s:[/b] (x%d interactions)\n%s\n" % [
			partner_name,
			conv.get("interaction_count", 1),
			conv.get("summary", "No summary")
		]
	
	conv_label.text = conv_text if conv_text else "No conversations yet"
