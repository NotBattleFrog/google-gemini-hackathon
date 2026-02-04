extends Node2D
class_name DialogueBubble

@onready var label = $RichTextLabel
@onready var bubble_bg = $BubbleBackground
@onready var timer = $TypewriterTimer

var full_text: String = ""
var current_text: String = ""
var char_index: int = 0
var emotion: String = "NEUTRAL"

func _ready() -> void:
    visible = false
    label.bbcode_enabled = true

func speak(text: String, new_emotion: String = "NEUTRAL") -> void:
    full_text = text
    emotion = new_emotion
    current_text = ""
    char_index = 0
    visible = true
    
    # Emotional formatting
    var display_text = full_text
    if emotion == "ANGER":
        display_text = "[shake rate=20 level=10]" + display_text + "[/shake]"
        modulate = Color(1.0, 0.8, 0.8) # Reddish tint
    elif emotion == "FEAR":
        display_text = "[wave amp=50 freq=5]" + display_text + "[/wave]"
        modulate = Color(0.8, 0.8, 1.0) # Bluish tint
    else:
        modulate = Color.WHITE
        
    label.text = display_text
    label.visible_ratio = 0.0 # Start hidden for typewriter
    
    # Dynamic sizing based on text length
    # Rough estimate: ~6-7 pixels per character for font size 12
    var char_width = 6.5
    var max_width = 200.0 # Maximum bubble width
    var min_width = 80.0
    var padding = 10.0
    
    var estimated_width = text.length() * char_width
    var bubble_width = clamp(estimated_width + padding * 2, min_width, max_width)
    
    # Calculate height based on wrapping
    var chars_per_line = int((bubble_width - padding * 2) / char_width)
    var num_lines = ceil(float(text.length()) / float(chars_per_line))
    var line_height = 16.0 # Font size 12 + spacing
    var bubble_height = clamp(num_lines * line_height + padding * 2, 30.0, 150.0)
    
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
    
    timer.start()
    
    # Auto-dismiss after expected reading time (0.05s per char + 2s base)
    var read_time = (text.length() * 0.05) + 2.0
    get_tree().create_timer(read_time).timeout.connect(func(): queue_free())

func _on_typewriter_timer_timeout() -> void:
    if label.visible_ratio < 1.0:
        label.visible_ratio += 0.05 # Reveal chunk
    else:
        timer.stop()
