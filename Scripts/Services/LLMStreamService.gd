extends Node

# Signals
signal token_received(text_chunk: String)
signal response_complete(full_text: String)
signal logic_received(json_payload: Dictionary)
signal connections_closed

# Configuration
const HOST = "generativelanguage.googleapis.com"
const PORT = 443
const ENDPOINT = "/v1beta/models/gemini-2.5-flash:streamGenerateContent" # Reverted to stable model

# State
var client: HTTPClient
var api_key: String = ""
var is_streaming: bool = false
var response_buffer: PackedByteArray
var full_response_accumulator: String = ""
var current_mode: String = "CHAT" # CHAT or LOGIC

# Context Window (Sliding)
var context_window: Array[Dictionary] = []

func _ready() -> void:
	client = HTTPClient.new()
	# Don't cache API key here - always read from ConfigManager when needed
	# This ensures ConfigManager is the single source of truth
	api_key = ""  # Clear any cached value
	
	# Log ConfigManager API key status (masked for security)
	if ConfigManager.api_key and ConfigManager.api_key.length() >= 20:
		var masked_key = ConfigManager.api_key.substr(0, 10) + "..." + ConfigManager.api_key.substr(ConfigManager.api_key.length() - 4)
		print("[LLMStreamService] ConfigManager API Key available: %s (length: %d)" % [masked_key, ConfigManager.api_key.length()])
	else:
		print("[LLMStreamService] WARNING: ConfigManager API Key is invalid! Value: '%s' (length: %d)" % [ConfigManager.api_key, ConfigManager.api_key.length()])
		print("[LLMStreamService] Will use fallback key when making requests.")
	
	# Ensure this runs even when paused (streaming doesn't stop)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not is_streaming:
		return
		
	client.poll()
	var status = client.get_status()
	
	match status:
		HTTPClient.STATUS_BODY:
			# We have data!
			var chunk = client.read_response_body_chunk()
			if chunk.size() > 0:
				print("[LLM DEBUG] Received chunk of size: ", chunk.size())
				_parse_chunk(chunk)
			else:
				# Keep alive?
				pass
				
		HTTPClient.STATUS_CONNECTED:
			# Still connected, waiting for body or keep-alive
			# print("[LLM DEBUG] Connected, waiting for data...") # Too noisy
			pass
			
		HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CONNECTION_ERROR:
			print("[LLM DEBUG] Connection closed. Status: ", status)
			# Done
			is_streaming = false
			emit_signal("connections_closed")
			if current_mode == "CHAT":
				emit_signal("response_complete", full_response_accumulator)
			elif current_mode == "LOGIC":
				var full_json_text = response_buffer.get_string_from_utf8()
				print("[LLM DEBUG] Logic Buffer: ", full_json_text)
				
				# Pre-clean JSON before parsing (extract content between braces)
				var start = full_json_text.find("{")
				var end = full_json_text.rfind("}")
				if start != -1 and end != -1:
					full_json_text = full_json_text.substr(start, end - start + 1)
				
				var json = JSON.new()
				if json.parse(full_json_text) == OK:
					emit_signal("logic_received", json.data)
				else:
					push_error("[LLM] JSON parse error: %s" % json.get_error_message())

		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_REQUESTING:
			pass # Working...
			
		_:
			print("[LLM DEBUG] Unexpected status: ", status)

func request_inference(system_prompt: String, user_input: String, mode: String = "CHAT") -> void:
	# Always read API key from ConfigManager (single source of truth)
	# Never use cached api_key variable - always read fresh from ConfigManager
	var current_api_key = ConfigManager.api_key
	if current_api_key.is_empty() or current_api_key.length() < 20:
		# Fallback to default if ConfigManager doesn't have one or has invalid key
		current_api_key = "AIzaSyCWgSRFKv_vEZSFZkbawDmYlHgaNwaR5Io"
		print("[LLM DEBUG] Using fallback API key (ConfigManager had invalid key: '%s')" % ConfigManager.api_key)
	
	# Log what we're about to use
	print("[LLM DEBUG] ConfigManager.api_key length: %d" % ConfigManager.api_key.length())
	print("[LLM DEBUG] Current API key to use length: %d" % current_api_key.length())
	
	# 1. API Key Check
	if current_api_key.is_empty():
		print("[LLM DEBUG] Error: No API Key found.")
		push_error("LLMService: No API Key.")
		emit_signal("response_complete", "Error: No API Key configured.")
		return
	
	# Use the fresh key
	api_key = current_api_key
		
	if is_streaming:
		print("[LLM DEBUG] Warning: Stream busy. Ignoring request.")
		return

	current_mode = mode
	print("[LLM DEBUG] Connecting to Gemini API...")
	var err = client.connect_to_host(HOST, PORT, TLSOptions.client())
	if err != OK:
		print("[LLM DEBUG] Error: Connection request failed. Error code: ", err)
		emit_signal("response_complete", "Error: Connection failed.")
		return
		
	# Wait for connection
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
		
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		print("[LLM DEBUG] Error: Could not connect to host. Status: ", client.get_status())
		emit_signal("response_complete", "Error: Could not reach Google API.")
		return
		
	print("[LLM DEBUG] Connection established. Sending request...")
	
	# Log API key being used (masked for security)
	var masked_key = api_key.substr(0, 10) + "..." + api_key.substr(api_key.length() - 4)
	print("[LLM DEBUG] Using API Key: %s (full length: %d)" % [masked_key, api_key.length()])
	print("[LLM DEBUG] Full API Key (for debugging): %s" % api_key)
	print("[LLM DEBUG] ConfigManager.api_key (for comparison): %s" % ConfigManager.api_key)
		
	# Build Request
	var url = ENDPOINT + "?key=" + api_key
	var headers = ["Content-Type: application/json"]
	
	print("[LLM DEBUG] Request URL (without key): %s?key=[REDACTED]" % ENDPOINT)
	
	var body_dict = {
		"contents": [{
			"parts": [{"text": system_instruction(system_prompt) + "\nUser: " + user_input}]
		}],
		"generationConfig": {
			"responseMimeType": "application/json" if mode == "LOGIC" else "text/plain"
		}
	}
	
	var body = JSON.stringify(body_dict)
	client.request(HTTPClient.METHOD_POST, url, headers, body)
	
	is_streaming = true
	response_buffer.clear()
	full_response_accumulator = ""

func _parse_chunk(chunk: PackedByteArray) -> void:
	# Gemini Stream returns format: "data: { ... }\n\n"
	# We need to buffer and parse SSE (Server-Sent Events) lines
	# For prototype, we treat text simply.
	
	var text_data = chunk.get_string_from_utf8()
	print("[LLM DEBUG] Raw Chunk Text: ", text_data.strip_edges()) # Debugging
	
	# Very basic parsing for SSE "data: " lines
	# In a real impl, we'd need a robust buffer parser for split JSONs.
	
	if current_mode == "CHAT":
		var clean_text = text_data.strip_edges()
		
		# Handle JSON Array Stream format: [ {...}, {...} ]
		if clean_text.begins_with("["):
			clean_text = clean_text.substr(1)
		if clean_text.ends_with("]"):
			clean_text = clean_text.substr(0, clean_text.length() - 1)
			# End of Stream detected
			print("[LLM DEBUG] End of stream detected (found ']'). Closing.")
			is_streaming = false
			client.close()
			emit_signal("connections_closed")
			if current_mode == "CHAT":
				emit_signal("response_complete", full_response_accumulator)

		if clean_text.begins_with(","):
			clean_text = clean_text.substr(1)
			
		clean_text = clean_text.strip_edges()
		if clean_text.is_empty(): return
		
		var json = JSON.parse_string(clean_text)
		if json and "candidates" in json:
			var candidates = json["candidates"]
			if candidates.size() > 0:
				var parts = candidates[0].get("content", {}).get("parts", [])
				if parts.size() > 0:
					var text = parts[0].get("text", "")
					emit_signal("token_received", text)
					full_response_accumulator += text
					 
	elif current_mode == "LOGIC":
		# Buffer everything
		response_buffer.append_array(chunk)
		
		# Check for Stream End (similar to CHAT)
		var partial_text = chunk.get_string_from_utf8().strip_edges()
		if partial_text.ends_with("]"):
			print("[LLM DEBUG] LOGIC Stream End detected (found ']'). Closing.")
			is_streaming = false
			client.close()
			emit_signal("connections_closed")
			
			# Process Accumulated Buffer
			var full_json_text = response_buffer.get_string_from_utf8()
			
			# Clean formatting ([ ... ])
			var clean = full_json_text.strip_edges()
			if clean.begins_with("["): clean = clean.substr(1)
			if clean.ends_with("]"): clean = clean.substr(0, clean.length() - 1)
			
			# Parse as JSON ARRAY of chunks
			var json_array_str = "[" + clean + "]"
			var json = JSON.new()
			
			print("[LLM DEBUG] Parsing Logic Stream Array...")
			
			if json.parse(json_array_str) == OK:
				var chunks = json.data
				if chunks is Array:
					# Concatenate all text parts from all chunks
					var full_text = ""
					for response_chunk in chunks:
						if "candidates" in response_chunk and response_chunk["candidates"].size() > 0:
							var parts = response_chunk["candidates"][0].get("content", {}).get("parts", [])
							for part in parts:
								if "text" in part:
									full_text += part["text"]
					
					print("[LLM DEBUG] Concatenated Logic Text: ", full_text.left(100) + "...")
					
					# Now parse the accumulated text as the game logic JSON
					# Remove markdown formatting if present
					full_text = full_text.replace("```json", "").replace("```", "").strip_edges()
					
					var logic_json = JSON.new()
					if logic_json.parse(full_text) == OK:
						print("[LLM DEBUG] Logic JSON Parsed Successfully!")
						emit_signal("logic_received", logic_json.data)
					else:
						print("[LLM DEBUG] Logic Inner JSON Parse Error: ", logic_json.get_error_message())
						print("[LLM DEBUG] Failed text: ", full_text)
			else:
				print("[LLM DEBUG] Logic Array Parse Error: ", json.get_error_message())

func system_instruction(prompt: String) -> String:
	return "System: " + prompt
