extends Node2D
class_name DialogueBubble

@onready var label = $RichTextLabel
@onready var bubble_bg = $BubbleBackground
@onready var timer = $TypewriterTimer

var full_text: String = ""
var current_text: String = ""
var char_index: int = 0
var emotion: String = "NEUTRAL"
var pages: Array[String] = []  # Array of text pages
var current_page: int = 0
var is_waiting_for_click: bool = false
var max_bubble_height: float = 150.0  # Maximum height before pagination

func _ready() -> void:
	visible = false
	label.bbcode_enabled = true
	# Make bubble clickable for pagination
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# If typewriter is still animating, skip to end
			if label.visible_ratio < 1.0:
				label.visible_ratio = 1.0
				timer.stop()
				# If there are more pages, wait for next click
				if current_page < pages.size() - 1:
					is_waiting_for_click = true
				return
			
			# If waiting for click (more pages available), go to next page
			if is_waiting_for_click:
				_next_page()
			# If on last page and clicked again, dismiss immediately
			elif current_page >= pages.size() - 1:
				queue_free()

func speak(text: String, new_emotion: String = "NEUTRAL") -> void:
	full_text = text
	emotion = new_emotion
	current_text = ""
	char_index = 0
	current_page = 0
	visible = true
	
	# Split text into pages if it's too long
	pages = _split_into_pages(text)
	
	# Show first page
	_show_page(0)
	
	timer.start()
	
	# Auto-dismiss after expected reading time (0.05s per char + 2s base)
	# Only auto-dismiss if single page or last page
	if pages.size() <= 1:
		var read_time = (text.length() * 0.05) + 2.0
		get_tree().create_timer(read_time).timeout.connect(func(): queue_free())

func _split_into_pages(text: String) -> Array[String]:
	var result: Array[String] = []
	
	# Calculate max characters per page based on bubble size
	var char_width = 6.5
	var max_width = 200.0
	var padding = 10.0
	var chars_per_line = int((max_width - padding * 2) / char_width)
	var line_height = 16.0
	var max_lines = int((max_bubble_height - padding * 2) / line_height)
	var max_chars_per_page = chars_per_line * max_lines
	
	# If text fits in one page, return as single page
	if text.length() <= max_chars_per_page:
		result.append(text)
		return result
	
	# Split into pages - try to break at word boundaries
	var remaining = text
	while remaining.length() > 0:
		if remaining.length() <= max_chars_per_page:
			result.append(remaining)
			break
		
		# Find last space before max_chars_per_page
		var cut_point = max_chars_per_page
		# Get substring up to cut_point, then find last space in it
		var search_text = remaining.substr(0, cut_point)
		var last_space = search_text.rfind(" ")
		if last_space > max_chars_per_page * 0.5:  # Only use space if it's not too early
			cut_point = last_space + 1
		
		result.append(remaining.substr(0, cut_point).strip_edges())
		remaining = remaining.substr(cut_point).strip_edges()
	
	return result

func _show_page(page_index: int) -> void:
	if page_index < 0 or page_index >= pages.size():
		return
	
	current_page = page_index
	var page_text = pages[page_index]
	
	# Emotional formatting
	var display_text = page_text
	if emotion == "ANGER":
		display_text = "[shake rate=20 level=10]" + display_text + "[/shake]"
		modulate = Color(1.0, 0.8, 0.8) # Reddish tint
	elif emotion == "FEAR":
		display_text = "[wave amp=50 freq=5]" + display_text + "[/wave]"
		modulate = Color(0.8, 0.8, 1.0) # Bluish tint
	else:
		modulate = Color.WHITE
	
	# Add page indicator if multiple pages
	if pages.size() > 1:
		display_text += "\n[color=gray][i](Page %d/%d - Click to continue)[/i][/color]" % [page_index + 1, pages.size()]
	
	label.text = display_text
	label.visible_ratio = 0.0 # Start hidden for typewriter
	
	# Dynamic sizing based on current page text length
	var char_width = 6.5
	var max_width = 200.0
	var min_width = 80.0
	var padding = 10.0
	
	var estimated_width = page_text.length() * char_width
	var bubble_width = clamp(estimated_width + padding * 2, min_width, max_width)
	
	# Calculate height based on wrapping
	var chars_per_line = int((bubble_width - padding * 2) / char_width)
	var num_lines = ceil(float(page_text.length()) / float(chars_per_line))
	var line_height = 16.0
	var bubble_height = clamp(num_lines * line_height + padding * 2, 30.0, max_bubble_height)
	
	# Update bubble and label sizes
	var half_width = bubble_width / 2.0
	bubble_bg.offset_left = -half_width
	bubble_bg.offset_right = half_width
	bubble_bg.offset_top = -bubble_height - 5.0
	bubble_bg.offset_bottom = -5.0
	
	label.offset_left = -half_width + padding
	label.offset_right = half_width - padding
	label.offset_top = -bubble_height
	label.offset_bottom = 0.0
	
	# Set waiting state if there are more pages
	is_waiting_for_click = (current_page < pages.size() - 1)

func _next_page() -> void:
	if current_page < pages.size() - 1:
		_show_page(current_page + 1)
		timer.start()  # Restart typewriter effect
	else:
		# Last page - set waiting state so clicking again will dismiss
		is_waiting_for_click = true
		# Also auto-dismiss after reading time
		var read_time = (pages[current_page].length() * 0.05) + 2.0
		get_tree().create_timer(read_time).timeout.connect(func(): 
			if is_instance_valid(self):
				queue_free()
		)

func _on_typewriter_timer_timeout() -> void:
	if label.visible_ratio < 1.0:
		label.visible_ratio += 0.05 # Reveal chunk
	else:
		timer.stop()
		# After typewriter completes, if there are more pages, wait for click
		if current_page < pages.size() - 1:
			is_waiting_for_click = true
