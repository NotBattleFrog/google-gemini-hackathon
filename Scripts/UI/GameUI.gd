extends CanvasLayer

@onready var gold_label = $TopBar/HBoxContainer/GoldLabel
@onready var wave_label = $TopBar/HBoxContainer/WaveLabel
@onready var hp_label = $TopBar/HBoxContainer/HPLabel

var time_label: Label  # Optional - will be set if exists

# New Diplomacy System
var diplomacy_panel_scene = preload("res://Scenes/UI/DiplomacyPanel.tscn")
var diplomacy_panel_instance: Control

# API Key Settings Panel
var api_key_panel: Panel
var api_key_input: LineEdit
var api_key_status_label: Label

# OLD (Removing)
# @onready var dialogue_panel = $DialoguePanel
# @onready var dialogue_text = $DialoguePanel/VBoxContainer/RichTextLabel
# @onready var input_field = $DialoguePanel/VBoxContainer/HBoxContainer/LineEdit
# @onready var send_button = $DialoguePanel/VBoxContainer/HBoxContainer/SendButton

func _ready() -> void:
	# Get optional time label
	time_label = get_node_or_null("TopBar/HBoxContainer/TimeLabel")
	
	# Connect signals
	GlobalSignalBus.gold_changed.connect(_on_gold_changed)
	GlobalSignalBus.wave_ended.connect(_on_wave_ended)
	
	if EconomyManager:
		EconomyManager.resources_changed.connect(func(g,i,m): update_labels())
	# Assume we might have an HP changed signal or just polling/custom logic
	# Adding a signal for HP to GlobalSignalBus would be good, but for now let's assume we update it manually or via a new signal
	
	# Initialize UI
	update_labels()
	update_time_display()
	
	# Update time display only once per second (not every frame)
	var time_update_timer = Timer.new()
	time_update_timer.wait_time = 1.0
	time_update_timer.autostart = true
	time_update_timer.timeout.connect(update_time_display)
	add_child(time_update_timer)

func update_time_display() -> void:
	if not time_label:
		return
	if has_node("/root/Game"):
		var game = get_node("/root/Game")
		if "current_day" in game and "time_of_day" in game:
			var day = game.current_day
			var hour = int(game.time_of_day)
			var minute = int((game.time_of_day - hour) * 60)
			var time_str = "%02d:%02d" % [hour, minute]
			var period = "Morning" if hour < 12 else "Afternoon" if hour < 18 else "Night"
			time_label.text = "Day %d | %s | %s" % [day, time_str, period]
	
	# Initialize UI
	update_labels()
	
	# Instantiate Diplomacy Panel
	diplomacy_panel_instance = diplomacy_panel_scene.instantiate()
	add_child(diplomacy_panel_instance)
	diplomacy_panel_instance.name = "DiplomacyPanel" # For Player.gd to find
	diplomacy_panel_instance.visible = false
	
	# Instantiate Time Dial
	var dial = preload("res://Scenes/UI/TimeDial.tscn").instantiate()
	add_child(dial)
	
	# Setup API Key Panel
	_setup_api_key_panel()
	
	process_mode = Node.PROCESS_MODE_ALWAYS # UI must work while paused

func update_labels() -> void:
	if SaveManager.current_state:
		# Use Icons for cleaner look
		gold_label.text = "💰 %d" % SaveManager.current_state.get("gold", 0)
		wave_label.text = "🌊 %d" % SaveManager.current_state.get("wave_number", 1)
		
		var hp = SaveManager.current_state.get("castle_hp", 100)
		# Dynamic Castle Icon based on HP
		var castle_icon = "🏰"
		if hp < 50: castle_icon = "🏚️"
		if hp < 20: castle_icon = "🔥"
		hp_label.text = "%s %d" % [castle_icon, hp]
	
	# Append Economy Stats to TopBar
	if EconomyManager and WaveManager:
		hp_label.text += "   ⛏️ %d (☁️ %.1f)   💧 %d (🟣 %.1f)" % [
			EconomyManager.iron, WaveManager.west_pollution,
			EconomyManager.mana, WaveManager.east_corruption
		]

func _on_gold_changed(new_amount: int) -> void:
	gold_label.text = "Gold: %d" % new_amount

func _on_wave_ended() -> void:
	# Maybe show dialogue panel here automatically?
	pass
	
func show_dialogue(npc_name: String) -> void:
	# Deprecated wrapper
	start_diplomacy(npc_name, "You are " + npc_name + ".")

func start_diplomacy(npc_name: String, persona: String) -> void:
	if diplomacy_panel_instance:
		diplomacy_panel_instance.setup(npc_name, persona)
		diplomacy_panel_instance.visible = true
		get_tree().paused = true
	else:
		push_error("GameUI: DiplomacyPanel not found.")

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
		if api_key_panel and api_key_panel.visible:
			_on_close_api_key_panel()
		else:
			_toggle_api_key_panel()

func _toggle_api_key_panel() -> void:
	if api_key_panel:
		api_key_panel.visible = not api_key_panel.visible
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
