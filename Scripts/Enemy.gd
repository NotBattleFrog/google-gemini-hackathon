extends CharacterBody2D

@export var speed: float = 100.0
@export var damage: int = 10
@export var attack_range: float = 60.0

var target_node: Node2D = null

func _ready() -> void:
    # Find Castle by group "Castle" or name
    # Ensure castle is in group in the scene or code
    var castles = get_tree().get_nodes_in_group("Castle")
    if castles.size() > 0:
        target_node = castles[0]
    
    # Scale difficulty
    var difficulty = SaveManager.current_state.get("difficulty_level", 1)
    if difficulty == 2: # Hard
        speed *= 1.5
        damage *= 2

func _physics_process(delta: float) -> void:
    if target_node == null:
        return
        
    var dist = global_position.distance_to(target_node.global_position)
    
    if dist > attack_range:
        # Move towards castle (assume castle is at x=0 usually, but let's be dynamic)
        var direction = (target_node.global_position - global_position).normalized()
        velocity.x = direction.x * speed
        
        # Simple gravity if needed, but for side scroller often enemies just walk on ground
        if not is_on_floor():
            velocity.y += 980 * delta
            
        move_and_slide()
    else:
        # Attack Logic (Simple timer based or frame based)
        # For prototype, just hit and die or hit continuously?
        # Let's hit and die for simplicity for now, or cooldown.
        # Impl: Cooldown
        _attack_target(delta)

var attack_cooldown: float = 0.0
func _attack_target(delta: float) -> void:
    if attack_cooldown <= 0:
        if target_node.has_method("take_damage"):
            target_node.take_damage(damage)
            attack_cooldown = 1.0 # 1 attack per second
    else:
        attack_cooldown -= delta
