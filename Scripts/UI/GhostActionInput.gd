extends Control

@onready var panel = $Panel
@onready var input_field = $Panel/VBoxContainer/InputField
@onready var submit_btn = $Panel/VBoxContainer/HBoxContainer/SubmitBtn
@onready var cancel_btn = $Panel/VBoxContainer/HBoxContainer/CancelBtn
@onready var status_label = $Panel/VBoxContainer/StatusLabel
@onready var character_list = $Panel/VBoxContainer/CharacterList

var turn_based_state: Node  # Will be cast to TurnBasedGameState
var selected_character: Node = null

func _ready() -> void:
	visible = true  # Ensure Control node is visible
	panel.visible = false
	
	# Wait a frame to ensure TurnBasedGameState is ready
	await get_tree().process_frame
	
	# Find TurnBasedGameState
	var tbs_node = get_node_or_null("/root/Game/TurnBasedGameState")
	if not tbs_node:
		push_error("GhostActionInput: TurnBasedGameState not found!")
		# Retry after a delay
		await get_tree().create_timer(0.5).timeout
		tbs_node = get_node_or_null("/root/Game/TurnBasedGameState")
		if not tbs_node:
			push_error("GhostActionInput: TurnBasedGameState still not found after retry!")
			return
	
	turn_based_state = tbs_node  # Store as Node, will access methods dynamically
	
	# Connect to ghost action requested signal
	_connect_to_signal(tbs_node)
	
	# Setup character list
	_setup_character_list()

func _connect_to_signal(tbs_node: Node) -> void:
	if not tbs_node:
		return
	
	if tbs_node.has_signal("ghost_action_requested"):
		if not tbs_node.ghost_action_requested.is_connected(_on_ghost_action_requested):
			tbs_node.ghost_action_requested.connect(_on_ghost_action_requested)
			print("[GhostActionInput] Connected to ghost_action_requested signal")
		else:
			print("[GhostActionInput] Already connected to ghost_action_requested signal")
	else:
		push_error("GhostActionInput: TurnBasedGameState does not have ghost_action_requested signal!")
		# Retry connection after a delay
		await get_tree().create_timer(1.0).timeout
		if tbs_node.has_signal("ghost_action_requested"):
			if not tbs_node.ghost_action_requested.is_connected(_on_ghost_action_requested):
				tbs_node.ghost_action_requested.connect(_on_ghost_action_requested)
				print("[GhostActionInput] Connected to ghost_action_requested signal (retry)")

func _setup_character_list() -> void:
	character_list.clear()
	character_list.add_item("All Characters (Public)", 0)
	
	var units = get_tree().get_nodes_in_group("Units")
	var npc_units = []
	for unit in units:
		# Skip Somchai (player) - can't target yourself
		if unit.soul and unit.soul.personality.name == "Somchai":
			continue
		npc_units.append(unit)

	var npc_index = 1
	for unit in npc_units:
		if unit.soul:
			var name = unit.soul.personality.name
			character_list.add_item(name, npc_index)
			npc_index += 1
	
	character_list.selected = 0
	# Only connect if not already connected
	if not character_list.item_selected.is_connected(_on_character_selected):
		character_list.item_selected.connect(_on_character_selected)

func _on_character_selected(index: int) -> void:
	if index == 0:
		selected_character = null
		status_label.text = "Public action - all characters will hear"
		status_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
	else:
		var units = get_tree().get_nodes_in_group("Units")
		var npc_units = []
		for unit in units:
			if unit.soul and unit.soul.personality.name != "Somchai":
				npc_units.append(unit)
		
		if index - 1 < npc_units.size():
			selected_character = npc_units[index - 1]
			if selected_character.soul:
				status_label.text = "Whisper to %s" % selected_character.soul.personality.name
			status_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))

func _on_ghost_action_requested() -> void:
	print("[GhostActionInput] Ghost action requested!")
	print("[GhostActionInput] Panel exists: %s, visible: %s" % [panel != null, panel.visible if panel else "N/A"])
	print("[GhostActionInput] Control node visible: %s, in tree: %s" % [visible, is_inside_tree()])
	
	# Wait 2 seconds before showing UI
	await get_tree().create_timer(2.0).timeout
	
	# Use call_deferred to ensure UI updates happen properly
	call_deferred("_show_input_panel")

func _show_input_panel() -> void:
	print("[GhostActionInput] ===== _show_input_panel CALLED =====")
	
	# Ensure @onready variables are ready
	if not panel:
		panel = $Panel
		print("[GhostActionInput] Panel found via $Panel: %s" % (panel != null))
	if not input_field:
		input_field = $Panel/VBoxContainer/InputField
	if not status_label:
		status_label = $Panel/VBoxContainer/StatusLabel
	
	if not panel:
		push_error("[GhostActionInput] Panel is null! Cannot show input panel.")
		# Try to find it another way
		for child in get_children():
			if child.name == "Panel":
				panel = child
				print("[GhostActionInput] Found Panel by iterating children")
				break
		if not panel:
			return
	
	print("[GhostActionInput] Panel exists: %s" % (panel != null))
	
	# Make Control node fill entire screen and be on top
	visible = true
	set_process_mode(Node.PROCESS_MODE_ALWAYS)  # Process even when paused
	
	# Force bring to front
	var parent_node = get_parent()
	if parent_node:
		parent_node.move_child(self, -1)
		print("[GhostActionInput] Moved to front of parent")
	
	# Make panel very visible - bright background, large size
	panel.visible = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.modulate = Color.WHITE  # Ensure no transparency
	print("[GhostActionInput] Panel visible set to: %s" % panel.visible)
	
	# Modern, clean styling
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.2, 0.98)  # Dark modern background
	style_box.border_color = Color(0.4, 0.5, 0.7, 1.0)  # Subtle blue border
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.shadow_color = Color(0, 0, 0, 0.5)
	style_box.shadow_size = 8
	style_box.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style_box)
	
	# Position at top center - align with viewport
	var viewport_size = get_viewport().get_visible_rect().size
	panel.anchor_left = 0.5
	panel.anchor_top = 0.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.0
	panel.offset_left = -400.0  # 800px wide, centered
	panel.offset_top = -180.0  # Position above viewport (negative offset)
	panel.offset_right = 400.0
	panel.offset_bottom = -30.0  # 150px tall, positioned above screen
	
	# Bring to front - move to end of parent's children (reuse parent_node from above)
	if parent_node:
		parent_node.move_child(self, -1)  # Move this Control to front
	if panel.get_parent() == self:
		move_child(panel, -1)  # Move panel to front within this Control
	
	# Ensure panel is properly sized (reuse viewport_size from above)
	if panel.size.x == 0 or panel.size.y == 0:
		print("[GhostActionInput] WARNING: Panel size is zero! Size: %s, forcing resize..." % panel.size)
		panel.size = Vector2(800, 150)
	
	# Ensure input field has enough height
	if input_field:
		input_field.custom_minimum_size = Vector2(0, 80)
	
	if input_field:
		input_field.text = ""
		input_field.grab_focus()
		input_field.editable = true
	
	# Force update
	queue_redraw()
	panel.queue_redraw()
	
	# Force show again after a frame
	await get_tree().process_frame
	visible = true
	panel.visible = true
	
	print("[GhostActionInput] ===== FINAL STATE =====")
	print("[GhostActionInput] Panel visible: %s" % panel.visible)
	print("[GhostActionInput] Control visible: %s" % visible)
	print("[GhostActionInput] Panel in tree: %s" % panel.is_inside_tree())
	print("[GhostActionInput] Panel size: %s" % panel.size)
	print("[GhostActionInput] Panel position: %s" % panel.position)
	print("[GhostActionInput] Viewport size: %s" % get_viewport().get_visible_rect().size)
	print("[GhostActionInput] =======================")
	
	# Check if this is Somchai's turn or end-of-round ghost action
	var is_somchai_turn = false
	if turn_based_state and "turn_order" in turn_based_state and "current_character_index" in turn_based_state:
		var turn_order = turn_based_state.turn_order
		var char_index = turn_based_state.current_character_index
		if char_index < turn_order.size():
			var current_char = turn_order[char_index]
			if current_char and "soul" in current_char and current_char.soul and current_char.soul.personality.name == "Somchai":
				is_somchai_turn = true
	
	if is_somchai_turn:
		status_label.text = "Enter your action"
	else:
		status_label.text = "Enter your ghost action"
	
	# Refresh character list
	_setup_character_list()

func _on_submit_pressed() -> void:
	var action_text = input_field.text.strip_edges()
	if action_text.is_empty():
		status_label.text = "Please enter an action!"
		status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
		return
	
	if not turn_based_state:
		status_label.text = "Error: TurnBasedGameState not found!"
		return
	
	# Submit ghost action (call method dynamically)
	if turn_based_state.has_method("submit_ghost_action"):
		turn_based_state.submit_ghost_action(action_text, selected_character)
	else:
		status_label.text = "Error: submit_ghost_action method not found!"
	
	# Hide panel
	panel.visible = false
	status_label.text = ""
	input_field.text = ""

func _on_cancel_pressed() -> void:
	panel.visible = false
	input_field.text = ""
	status_label.text = ""

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Toggle panel with 'x' key
		if event.keycode == KEY_X:
			_toggle_panel()
		# Handle Enter/Escape when panel is visible
		elif panel.visible:
			if event.keycode == KEY_ENTER:
				_on_submit_pressed()
			elif event.keycode == KEY_ESCAPE:
				_on_cancel_pressed()

func _toggle_panel() -> void:
	if not panel:
		return
	
	if panel.visible:
		# Hide panel
		panel.visible = false
		print("[GhostActionInput] Panel hidden via X key")
	else:
		# Show panel
		_show_input_panel()
		print("[GhostActionInput] Panel shown via X key")
