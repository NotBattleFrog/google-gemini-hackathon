extends CanvasLayer

# API Key Settings Panel
var api_key_panel: Panel
var api_key_input: LineEdit
var api_key_status_label: Label	

@onready var api_config_panel = $APIKeyPanel # Assuming APIKeyPanel is the node name created by _setup_api_key_panel()
@onready var turn_counter_label = null  # Created dynamically

func _ready() -> void:
	# Setup API Key Panel (still needed to create the panel)
	_setup_api_key_panel()
	print("[GameUI] Ready - API key panel initialized")
	
	# Create turn counter label
	_create_turn_counter_label()
	
	# Connect to TurnBasedGameState if available
	await get_tree().process_frame
	var tbs = get_node_or_null("/root/Game/TurnBasedGameState")
	if tbs:
		if tbs.has_signal("turn_counter_updated"):
			tbs.turn_counter_updated.connect(_on_turn_counter_updated)
			print("[GameUI] Connected to turn_counter_updated signal")
	
	# Hide API panel by default
	if api_config_panel:
		api_config_panel.visible = false

func _create_turn_counter_label() -> void:
	# Create a label at the top center of screen
	turn_counter_label = Label.new()
	turn_counter_label.name = "TurnCounterLabel"
	turn_counter_label.text = "Waiting for game start..."
	
	# Position at top center
	turn_counter_label.anchor_left = 0.5
	turn_counter_label.anchor_top = 0.0
	turn_counter_label.anchor_right = 0.5
	turn_counter_label.anchor_bottom = 0.0
	turn_counter_label.offset_left = -200
	turn_counter_label.offset_top = 20
	turn_counter_label.offset_right = 200
	turn_counter_label.offset_bottom = 60
	turn_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Styling
	turn_counter_label.add_theme_font_size_override("font_size", 24)
	turn_counter_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 1.0))
	turn_counter_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	turn_counter_label.add_theme_constant_override("outline_size", 4)
	
	add_child(turn_counter_label)

func _on_turn_counter_updated(turns_until_player: int, current_character: String) -> void:
	if not turn_counter_label:
		return
	
	if turns_until_player == 0:
		turn_counter_label.text = "YOUR TURN!"
		turn_counter_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))
	elif turns_until_player == 1:
		turn_counter_label.text = "Next: YOUR TURN (after %s)" % current_character
		turn_counter_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3, 1.0))
	else:
		turn_counter_label.text = "%d turns until your action (Now: %s)" % [turns_until_player, current_character]
		turn_counter_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 1.0))

func _setup_api_key_panel() -> void:
	# Create API Key Settings Panel
	api_key_panel = Panel.new()
	api_key_panel.name = "APIKeyPanel"
	api_key_panel.visible = false
	
	# Center the panel properly
	api_key_panel.set_anchors_preset(Control.PRESET_CENTER)
	api_key_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	api_key_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	api_key_panel.custom_minimum_size = Vector2(500, 300)
	api_key_panel.offset_left = -250  # Half of width
	api_key_panel.offset_top = -150   # Half of height
	api_key_panel.offset_right = 250
	api_key_panel.offset_bottom = 150
	
	# Add visible background styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)  # Dark blue-gray
	style.border_color = Color(0.4, 0.6, 0.8, 1.0)  # Light blue border
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	api_key_panel.add_theme_stylebox_override("panel", style)
	
	add_child(api_key_panel)
	
	# Container
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	api_key_panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "API Key Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)
	
	# Info Label
	var info_label = Label.new()
	info_label.text = "Enter your Google Gemini API Key:"
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(info_label)
	
	# Input Field
	api_key_input = LineEdit.new()
	api_key_input.placeholder_text = "Paste API Key Here..."
	api_key_input.secret = true
	api_key_input.text = ConfigManager.api_key
	vbox.add_child(api_key_input)
	
	# Status Label
	api_key_status_label = Label.new()
	api_key_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	api_key_status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
	vbox.add_child(api_key_status_label)
	
	# Buttons Container
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	# Save Button
	var save_btn = Button.new()
	save_btn.text = "Save Key"
	save_btn.pressed.connect(_on_save_api_key)
	hbox.add_child(save_btn)
	
	# Close Button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_close_api_key_panel)
	hbox.add_child(close_btn)
	
	# Update status
	_update_api_key_status()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_K:
		# Don't toggle API panel if player text input is active
		var ghost_input = get_node_or_null("/root/Game/GhostActionInput")
		if ghost_input and ghost_input.visible:
			return
		
		print("[GameUI] K key pressed! Panel visible: %s, Panel exists: %s" % [api_key_panel.visible if api_key_panel else "null", api_key_panel != null])
		if api_key_panel and api_key_panel.visible:
			_on_close_api_key_panel()
		else:
			_toggle_api_key_panel()

func _toggle_api_key_panel() -> void:
	if api_key_panel:
		api_key_panel.visible = not api_key_panel.visible
		print("[GameUI] Toggled API panel visibility to: %s" % api_key_panel.visible)
		if api_key_panel.visible:
			api_key_input.text = ConfigManager.api_key
			_update_api_key_status()

func _on_save_api_key() -> void:
	var key = api_key_input.text.strip_edges()
	if key.length() > 0:
		print("[GameUI] Saving API key (length: %d)" % key.length())
		ConfigManager.save_api_key(key)
		
		# Clear quota pause immediately when new key is saved
		var llm_service = get_node_or_null("/root/LLMStreamService")
		if llm_service:
			llm_service.quota_paused = false
			llm_service.quota_resume_timer = 0.0
			llm_service.quota_error_message = ""
			print("[GameUI] Cleared API quota pause - retrying immediately with new key")
		
		api_key_status_label.text = "✓ API Key saved! Retrying API calls..."
		api_key_status_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
		await get_tree().create_timer(1.5).timeout
		_update_api_key_status()
	else:
		api_key_status_label.text = "Key cannot be empty."
		api_key_status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))

func _on_close_api_key_panel() -> void:
	if api_key_panel:
		api_key_panel.visible = false

func _update_api_key_status() -> void:
	if api_key_status_label:
		if ConfigManager.api_key.is_empty():
			api_key_status_label.text = "⚠ No API Key set"
			api_key_status_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2, 1))
		else:
			api_key_status_label.text = "✓ API Key configured"
			api_key_status_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4, 1))
