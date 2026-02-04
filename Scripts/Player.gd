extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

func _ready():
	# Ghost Mode: No collisions
	collision_layer = 0
	collision_mask = 0
	# Note: Player sprite is set via modulate in Game.gd
	
func _physics_process(delta):
	# GHOST MODE: Flying, no gravity
	
	# Vertical Movement (W/S)
	var dir_y = 0
	if Input.is_key_pressed(KEY_W): dir_y -= 1
	if Input.is_key_pressed(KEY_S): dir_y += 1
	velocity.y = dir_y * SPEED
	
	# Horizontal Movement (A/D)
	var dir_x = 0
	if Input.is_key_pressed(KEY_A): dir_x -= 1
	if Input.is_key_pressed(KEY_D): dir_x += 1
	velocity.x = dir_x * SPEED

	move_and_slide()
