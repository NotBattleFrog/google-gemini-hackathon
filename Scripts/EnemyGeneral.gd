extends CharacterBody2D

signal parley_complete(decision: String)

@export var speed: float = 80.0
var state = "APPROACHING" # APPROACHING, WAITING, NEGOTIATING, LEAVING, ATTACKING
var target_x = 0.0 # Center needs to be reached roughly

func _ready() -> void:
    # Scale appearance or size to look distinct
    $ColorRect.color = Color(0.5, 0.0, 0.5, 1) # Purple
    GlobalSignalBus.response_received.connect(_on_llm_response)

func _physics_process(delta: float) -> void:
    match state:
        "APPROACHING":
            var direction = sign(target_x - global_position.x)
            velocity.x = direction * speed
            
            if not is_on_floor():
                velocity.y += 980 * delta
            
            move_and_slide()
            
            # Check for player proximity to show Prompt (Allow interception)
            var player = get_parent().find_child("Player", false, false)
            if player:
                var dist = global_position.distance_to(player.global_position)
                $PromptLabel.visible = (dist < 200)
            
            # Distance check increased to 150 because Castle collision (width ~100) might block him at ~70
            if abs(global_position.x - target_x) < 150:
                state = "WAITING"
                velocity.x = 0
                print("General: Arrived! I await your parley!")
        
        "WAITING":
            # Check for player proximity to show Prompt
            var player = get_parent().find_child("Player", false, false)
            if player:
                var dist = global_position.distance_to(player.global_position)
                $PromptLabel.visible = (dist < 200)
            
        "LEAVING":
            $PromptLabel.visible = false
            velocity.x = -100 # Walk away
            if not is_on_floor(): velocity.y += 980 * delta
            move_and_slide()
            if abs(global_position.x) > 1000:
                queue_free()

func interact() -> void:
    # Allow interaction if approaching or waiting
    if state == "WAITING" or state == "APPROACHING":
        state = "NEGOTIATING"
        $PromptLabel.visible = false
        # Find GameUI and open dialogue
        var ui = get_tree().root.find_child("GameUI", true, false)
        if ui:
            ui.start_diplomacy("General Iron-Hand", "You are General Iron-Hand. You are arrogant but pragmatic. If the player offers Gold, consider retreating. If they threaten you, ATTACK.")
        else:
            print("Error: GameUI not found.")

func _on_llm_response(text: String) -> void:
    if state != "NEGOTIATING": return
    
    # Parse decision
    if text.contains("[AGREE]"):
        state = "LEAVING"
        parley_complete.emit("AGREE")
        # UI update should happen in UI script or via signal, handled there
    elif text.contains("[ATTACK]"):
        state = "ATTACKING" # Or just disappear and spawn wave
        parley_complete.emit("ATTACK")
        queue_free()
