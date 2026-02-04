extends CharacterBody2D

@onready var prompt_label = $PromptLabel

func _ready() -> void:
    $ColorRect.color = Color(0.6, 0.4, 0.2) # Brown rags
    prompt_label.visible = false

func _physics_process(delta: float) -> void:
    # Simple gravity
    if not is_on_floor():
        velocity.y += 980 * delta
    move_and_slide()
    
    # Check player proximity
    var player = get_parent().find_child("Player", false, false)
    if player:
        var dist = global_position.distance_to(player.global_position)
        prompt_label.visible = (dist < 150)

func interact() -> void:
    print("Interacting with Vagrant")
    var ui = get_tree().root.find_child("GameUI", true, false)
    if ui:
        ui.start_diplomacy("The Vagrant", "You are a ragged Vagrant teaching the player about the world. Explain that Gold keeps units loyal, Iron creates pollution, and Mana spreads corruption. Ask for a coin.")
