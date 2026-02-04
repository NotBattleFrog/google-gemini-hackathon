extends Node

# Resources
var gold: int = 100
var iron: int = 0
var mana: int = 0

# Signals
signal resources_changed(gold: int, iron: int, mana: int)

func mine_iron() -> void:
	iron += 10
	# Feedback Loop: Mining Iron angers the East (Nature)
	# But strengthens West tech? Or actually increases West Pollution which makes West stronger/agressive?
	# Logic from prompt: "Mine Iron -> West gets stronger (more tech) BUT East gets angry (Nature's Wrath)"
	# Let's interpret: 
	#   Iron is used to build West defenses.
	#   Mining it increases West Pollution (Industrialization).
	
	var wave_manager = get_tree().root.find_child("WaveManager", true, false)
	if wave_manager:
		wave_manager.west_pollution += 1.0
		print("Economy: Mined Iron. West Pollution +1")
		
	emit_update()

func harvest_mana() -> void:
	mana += 10
	# Feedback Loop: Harvesting Mana increases East Corruption
	var wave_manager = get_tree().root.find_child("WaveManager", true, false)
	if wave_manager:
		wave_manager.east_corruption += 1.0
		print("Economy: Harvested Mana. East Corruption +1")
		
	emit_update()

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		emit_update()
		return true
	return false

func emit_update() -> void:
	emit_signal("resources_changed", gold, iron, mana)
