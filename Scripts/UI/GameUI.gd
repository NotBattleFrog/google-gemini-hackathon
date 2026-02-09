extends CanvasLayer

# API Key Settings Panel
var api_key_panel: Panel
var api_key_input: LineEdit
var api_key_status_label: Label	

func _ready() -> void:
	# Setup API Key Panel
	_setup_api_key_panel()
	print("[GameUI] Ready - API key panel initialized")


func _setup_api_key_panel() -> void:
	# Create API Key Settings Panel
	api_key_panel = Panel.new()
	api_key_panel.name = "APIKeyPanel"
	api_key_panel.visible = false
	api_key_panel.anchors_preset = Control.PRESET_CENTER
	api_key_panel.custom_minimum_size = Vector2(400, 250)
	api_key_panel.position = Vector2(-200, -125)
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
	vbox.add_child(title)
	
	# Info Label
	var info_label = Label.new()
	info_label.text = "Enter your Google Gemini API Key:"
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		# LLMStreamService will read from ConfigManager automatically
		api_key_status_label.text = "✓ API Key saved!"
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
