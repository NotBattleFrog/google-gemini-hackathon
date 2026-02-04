extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle Jump.
	if (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W)) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var direction = 0
	if Input.is_key_pressed(KEY_A):
		direction -= 1
	if Input.is_key_pressed(KEY_D):
		direction += 1
		
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	# Interaction
	if Input.is_key_pressed(KEY_E):
		_try_interact()

	# Economy Controls
	if Input.is_key_pressed(KEY_1):
		if EconomyManager:
			EconomyManager.mine_iron()
			
	if Input.is_key_pressed(KEY_2):
		if EconomyManager:
			EconomyManager.harvest_mana()

func _try_interact() -> void:
	# Check for Vagrant
	var vagrant = get_parent().find_child("Vagrant", false, false)
	if vagrant and global_position.distance_to(vagrant.global_position) < 200:
		vagrant.interact()
		return

	# Check for EnemyGeneral nearby
	var general = get_parent().find_child("EnemyGeneral", false, false)
	if general:
		var dist = global_position.distance_to(general.global_position)
		if dist < 200: # Interaction Range
			general.interact() # General should now call GameUI.start_diplomacy
			return
