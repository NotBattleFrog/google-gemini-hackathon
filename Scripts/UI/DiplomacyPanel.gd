class_name DiplomacyPanel
extends Control

@onready var response_box = $Panel/VBoxContainer/ResponseBox
@onready var input_line = $Panel/VBoxContainer/HBoxContainer/Input
@onready var send_button = $Panel/VBoxContainer/HBoxContainer/SendButton

var llm_service: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Ensure inputs work when paused
	
	# Use Autoload directly
	if LLMStreamService:
		llm_service = LLMStreamService
		# Connect signals
		if not LLMStreamService.token_received.is_connected(_on_token_received):
			LLMStreamService.token_received.connect(_on_token_received)
		if not LLMStreamService.logic_received.is_connected(_on_logic_received):
			LLMStreamService.logic_received.connect(_on_logic_received)
		if not LLMStreamService.response_complete.is_connected(_on_response_complete):
			LLMStreamService.response_complete.connect(_on_response_complete)
	else:
		push_error("DiplomacyPanel: LLMStreamService Autoload not found")

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"): # ESC
		_close_panel()

func _close_panel() -> void:
	visible = false
	get_tree().paused = false
	
func _on_send_button_pressed() -> void:
	_submit()

func _on_input_text_submitted(text: String) -> void:
	_submit()

func _submit() -> void:
	var text = input_line.text
	if text.is_empty(): return
	
	input_line.clear()
	response_box.append_text("\n[b]You:[/b] " + text + "\n")
	
	# Stream Request
	if LLMStreamService: # AutoLoad check
		LLMStreamService.request_inference(
			current_persona_prompt,
			text,
            "CHAT"
		)
	else:
		response_box.append_text("[color=red]Error: LLMStreamService not found.[/color]")

var current_npc_name: String = "General Iron-Hand"
var current_persona_prompt: String = "You are General Iron-Hand. Respond to the player."

func setup(npc_name: String, persona: String) -> void:
	current_npc_name = npc_name
	current_persona_prompt = persona
	$Panel/VBoxContainer/Title.text = "Parley with " + npc_name
	response_box.clear()
	response_box.append_text("[i]You approach %s...[/i]\n" % npc_name)

# Connect these in _ready or via Groups if LLMService is a singleton
func _on_token_received(chunk: String) -> void:
	response_box.add_text(chunk) # Typewriter effect naturally occurs via chunks
	
func _on_logic_received(payload: Dictionary) -> void:
	response_box.append_text("\n[color=yellow]Logic:[/color] " + str(payload))

func _on_response_complete(full_text: String) -> void:
	# Bridge to the rest of the game (e.g. EnemyGeneral)
	GlobalSignalBus.response_received.emit(full_text)
