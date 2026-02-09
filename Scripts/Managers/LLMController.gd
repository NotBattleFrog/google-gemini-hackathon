extends Node

# Signals (Local, can be connected to Global if needed, or we emit Global directly)
signal text_generated(response_text)
signal image_generated(image_texture)
signal error_occurred(error_message)

# Status signals
signal request_started
signal request_finished

var model_name: String = "gemini-2.5-flash"
var is_processing_request: bool = false


@onready var http_request_text = HTTPRequest.new()
# @onready var http_request_image = HTTPRequest.new() # Uncomment if we use image gen

func _ready():
	# Important: LLMController must run when game is paused (for Dialogue)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	add_child(http_request_text)
	http_request_text.request_completed.connect(_on_text_request_completed)

	# Listen for Social Requests
	if GlobalSignalBus:
		if not GlobalSignalBus.request_social_interaction.is_connected(_on_social_request):
			GlobalSignalBus.request_social_interaction.connect(_on_social_request)
		if not GlobalSignalBus.request_summary_merge.is_connected(_on_summary_merge_request):
			GlobalSignalBus.request_summary_merge.connect(_on_summary_merge_request)
		if not GlobalSignalBus.request_turn_action.is_connected(_on_turn_action_request):
			GlobalSignalBus.request_turn_action.connect(_on_turn_action_request)
	# Listen for LLM Stream Logic Results
	if LLMStreamService:
		if not LLMStreamService.logic_received.is_connected(_on_llm_logic_received):
			LLMStreamService.logic_received.connect(_on_llm_logic_received)
		# Fallback if logic comes as text (likely with 2.5-flash)
		if not LLMStreamService.response_complete.is_connected(_on_llm_response_complete):
			LLMStreamService.response_complete.connect(_on_llm_response_complete)

var pending_social_interaction: Dictionary = {}
var pending_turn_action: Dictionary = {}

func _on_social_request(soul_a: Node, soul_b: Node, prompt: String) -> void:
	if pending_social_interaction.size() > 0:
		print("LLMController: Social bus busy. Dropping request.")
		return
		
	print("LLMController: Processing social request for %s and %s" % [soul_a.name, soul_b.name])
	pending_social_interaction = {"soul_a": soul_a, "soul_b": soul_b}
	
	# Identify as LOGIC mode
	LLMStreamService.request_inference("You are a Game Master simulation engine.", prompt, "LOGIC")

func _on_llm_logic_received(payload: Dictionary) -> void:
	print("[LLMController] _on_llm_logic_received called with payload: ", payload)
	_handle_social_result(payload)

func _on_llm_response_complete(full_text: String) -> void:
	print("[LLMController] _on_llm_response_complete called")
	# If we are expecting a social result but got text (maybe JSON embedded in text)
	if pending_social_interaction.size() > 0:
		# Try to parse JSON from text
		var json = JSON.new()
		var err = json.parse(full_text)
		if err == OK:
			_handle_social_result(json.data)
		else:
			# Try to find JSON block ```json ... ```
			var start = full_text.find("{")
			var end = full_text.rfind("}")
			if start != -1 and end != -1:
				var json_sub = full_text.substr(start, end - start + 1)
				if json.parse(json_sub) == OK:
					_handle_social_result(json.data)
				else:
					print("LLMController: Failed to parse social JSON.")
					pending_social_interaction.clear()
			else:
				print("LLMController: No JSON parsing possible.")
				pending_social_interaction.clear()

func _handle_social_result(data: Dictionary) -> void:
	print("[LLMController] _handle_social_result called")
	if pending_social_interaction.is_empty(): 
		print("[LLMController] WARNING: No pending interaction!")
		return
	
	var soul_a = pending_social_interaction["soul_a"]
	var soul_b = pending_social_interaction["soul_b"]
	
	# Safety check for freed nodes
	if not is_instance_valid(soul_a):
		print("[LLMController] ERROR: soul_a was freed!")
		pending_social_interaction.clear()
		return
	
	if not is_instance_valid(soul_b):
		print("[LLMController] ERROR: soul_b was freed!")
		pending_social_interaction.clear()
		return
	
	print("[LLMController] Applying result to souls: ", soul_a.name, " and ", soul_b.name)
	
	soul_a.apply_interaction_result(data, soul_b)
	
	pending_social_interaction.clear()

func _on_chronicle_logic_received(payload: Dictionary) -> void:
	print("[LLMController] Chronicle logic received: ", payload)
	GlobalSignalBus.chronicle_generated.emit(payload)
	
	# Disconnect after use
	if LLMStreamService.logic_received.is_connected(_on_chronicle_logic_received):
		LLMStreamService.logic_received.disconnect(_on_chronicle_logic_received)

# Summary Merge System
var pending_summary_merge: Dictionary = {}

func _on_summary_merge_request(soul: Node, partner_name: String, prompt: String) -> void:
	if pending_summary_merge.size() > 0:
		print("[LLMController] Summary merge already in progress. Dropping request.")
		return
	
	print("[LLMController] Processing summary merge request for %s with %s" % [soul.personality.name, partner_name])
	pending_summary_merge = {"soul": soul, "partner_name": partner_name}
	
	# Use LOGIC mode for JSON response
	LLMStreamService.request_inference("You are a relationship summarizer.", prompt, "LOGIC")
	
	# Connect to response (one-time)
	if not LLMStreamService.logic_received.is_connected(_on_summary_merge_response):
		LLMStreamService.logic_received.connect(_on_summary_merge_response)

func _on_summary_merge_response(payload: Dictionary) -> void:
	print("[LLMController] Summary merge response received: ", payload)
	
	if pending_summary_merge.is_empty():
		print("[LLMController] WARNING: No pending summary merge!")
		return
	
	var soul = pending_summary_merge["soul"]
	var partner_name = pending_summary_merge["partner_name"]
	
	var merged_summary = payload.get("summary", "Had a conversation")
	
	if is_instance_valid(soul):
		soul._on_summary_merged(partner_name, merged_summary)
	
	pending_summary_merge.clear()
	
	# Disconnect
	if LLMStreamService.logic_received.is_connected(_on_summary_merge_response):
		LLMStreamService.logic_received.disconnect(_on_summary_merge_response)

# Turn-Based Action System
func _on_turn_action_request(character: Node, prompt: String) -> void:
	if pending_turn_action.size() > 0:
		print("[LLMController] Turn action already in progress. Dropping request.")
		return
	
	print("[LLMController] Processing turn action for %s" % character.soul.personality.name)
	pending_turn_action = {"character": character}
	
	# Use LOGIC mode for structured JSON response
	LLMStreamService.request_inference("You are a Game Master simulation engine for a murder mystery.", prompt, "LOGIC")
	
	# Connect to response (one-time)
	if not LLMStreamService.logic_received.is_connected(_on_turn_action_response):
		LLMStreamService.logic_received.connect(_on_turn_action_response)

func _on_turn_action_response(payload: Dictionary) -> void:
	print("[LLMController] Turn action response received: ", payload)
	
	if pending_turn_action.is_empty():
		print("[LLMController] WARNING: No pending turn action!")
		return
	
	var character = pending_turn_action["character"]
	
	if not is_instance_valid(character):
		print("[LLMController] ERROR: character was freed!")
		pending_turn_action.clear()
		return
	
	# Emit the result
	GlobalSignalBus.turn_action_completed.emit(character, payload)
	
	pending_turn_action.clear()
	
	# Disconnect
	if LLMStreamService.logic_received.is_connected(_on_turn_action_response):
		LLMStreamService.logic_received.disconnect(_on_turn_action_response)



func generate_text(prompt: String):
	if is_processing_request:
		return

	var api_key = ConfigManager.api_key
	if api_key.is_empty():
		emit_signal("error_occurred", "API Key missing")
		return

	# Log API key being used (masked for security)
	var masked_key = api_key.substr(0, 10) + "..." + api_key.substr(api_key.length() - 4)
	print("[LLMController] Using API Key: %s (full length: %d)" % [masked_key, api_key.length()])

	is_processing_request = true
	emit_signal("request_started")
	# GlobalSignalBus.response_received.emit("...Thinking...") # Removed: This was unlocking UI too early

	var url = "https://generativelanguage.googleapis.com/v1beta/models/" + model_name + ":generateContent?key=" + api_key
	print("[LLMController] Request URL (without key): %s:generateContent?key=[REDACTED]" % model_name)
	var headers = ["Content-Type: application/json"]
	
	# Structure for 'contents'
	var body_structure = {
		"contents": [{
			"parts": [{"text": prompt}]
		}]
	}
	
	var body = JSON.stringify(body_structure)
	
	print("Sending text request to Gemini...")
	var error = http_request_text.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		is_processing_request = false
		emit_signal("request_finished")
		emit_signal("error_occurred", "Failed to create HTTP request")
		GlobalSignalBus.response_received.emit("Error: Connection Failed.")

func _on_text_request_completed(result, response_code, headers, body):
	is_processing_request = false
	emit_signal("request_finished")
	
	if response_code != 200:
		var response_str = body.get_string_from_utf8()
		print("API Error: ", response_code, " ", response_str)
		var err_msg = "API Error: " + str(response_code)
		emit_signal("error_occurred", err_msg)
		GlobalSignalBus.response_received.emit(err_msg)
		return

	var json = JSON.new()
	var parse_err = json.parse(body.get_string_from_utf8())
	if parse_err == OK:
		var response = json.data
		if "candidates" in response and response.candidates.size() > 0:
			var content = response.candidates[0].content
			var text = ""
			if "parts" in content:
				for part in content.parts:
					if "text" in part:
						text += part.text
			
			# Success!
			print("Gemini Response: ", text)
			emit_signal("text_generated", text)
			GlobalSignalBus.response_received.emit(text)
		else:
			emit_signal("error_occurred", "No candidates in response")
			GlobalSignalBus.response_received.emit("Error: No candidates.")
	else:
		emit_signal("error_occurred", "Failed to parse JSON response")
		GlobalSignalBus.response_received.emit("Error: Bad JSON.")
