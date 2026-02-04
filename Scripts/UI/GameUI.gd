extends CanvasLayer

@onready var gold_label = $TopBar/HBoxContainer/GoldLabel
@onready var wave_label = $TopBar/HBoxContainer/WaveLabel
@onready var hp_label = $TopBar/HBoxContainer/HPLabel

var time_label: Label  # Optional - will be set if exists

# New Diplomacy System
var diplomacy_panel_scene = preload("res://Scenes/UI/DiplomacyPanel.tscn")
var diplomacy_panel_instance: Control

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
