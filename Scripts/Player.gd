extends Unit  # Extend Unit - Player is just like NPCs, no special movement needed

func _ready():
	# Ensure we're in the right groups (in case script replacement lost them)
	if not is_in_group("Units"):
		add_to_group("Units")
	if not is_in_group("Player"):
		add_to_group("Player")
	
	# Call parent _ready() first to set up Unit stuff
	super._ready()
	
	print("[Player] Player._ready() STARTING - name: %s, in Units: %s, in Player: %s" % [name, is_in_group("Units"), is_in_group("Player")])
	
	# Initialize turn-based state for Somchai
	if soul:
		var initial_knowledge = [
			"You are Somchai, murdered by a Neural Link overload",
			"You are now a ghost observing the investigation",
			"UNIT-7 is investigating your murder",
			"Madam Vanna, Dr. Aris, and Lila are suspects",
			"You can influence the investigation as a ghost"
		]
		soul.initialize_turn_based_state("You are Somchai, the victim. As a ghost, you can observe and influence the investigation. Your goal is to help reveal the truth about your murder.", initial_knowledge)
		print("[Player] Turn-based state initialized for Somchai")
	else:
		print("[Player] WARNING: Soul not found yet!")
	
	print("[Player] Player._ready() completed - name: %s, in Units group: %s, in Player group: %s" % [name, is_in_group("Units"), is_in_group("Player")])
