extends Control

@onready var menu_container = $MenuContainer
@onready var setup_panel = $SetupPanel
@onready var api_key_input = $SetupPanel/VBoxContainer/APIKeyInput
@onready var status_label = $SetupPanel/VBoxContainer/StatusLabel

# This scene expects nodes:
# - MenuContainer (VBoxContainer)
#   - NewGameBtn
#   - SettingsBtn
#   - ExitBtn
# - SetupPanel (Panel) -- Acts as settings and first-time setup
#   - VBoxContainer
#     - APIKeyInput (LineEdit)
#     - SaveBtn (Button)
#     - CloseBtn (Button)

func _ready() -> void:
	# Setup Live Background
	var game_preview = find_child("GamePreview", true, false)
	if game_preview:
		# Get the Game scene inside the SubViewport
		var viewport = game_preview.find_child("SubViewport", true, false)
		if viewport:
			# Pause all game logic in preview
			for child in viewport.get_children():
				if child.has_method("set_process_mode"):
					child.process_mode = Node.PROCESS_MODE_DISABLED
		
		# Disable Player Input in Menu
		var player = game_preview.find_child("Player", true, false)
		if player:
			player.set_physics_process(false)
			player.set_process_unhandled_input(false)
			
		# Hide UI in Menu
		var ui = game_preview.find_child("GameUI", true, false)
		if ui:
			ui.visible = false


func show_main_menu() -> void:
	menu_container.visible = true
	setup_panel.visible = false

func show_setup_mode(is_force: bool = false) -> void:
	menu_container.visible = not is_force
	setup_panel.visible = true
	api_key_input.text = ConfigManager.api_key
	
	# If forced (first time), hide the close button for the settings panel if it exists
	var close_btn = setup_panel.find_child("CloseBtn", true, false)
	if close_btn:
		close_btn.visible = not is_force

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")

func _on_settings_pressed() -> void:
	show_setup_mode(false)

func _on_save_settings_pressed() -> void:
	var key = api_key_input.text.strip_edges()
	if key.length() > 0:
		ConfigManager.save_api_key(key)
		status_label.text = "Keys saved!"
		await get_tree().create_timer(1.0).timeout
		show_main_menu()
	else:
		status_label.text = "Key cannot be empty."

func _on_close_settings_pressed() -> void:
	if ConfigManager.api_key.is_empty():
		status_label.text = "You must save a key first!"
	else:
		show_main_menu()

func _on_exit_pressed() -> void:
	get_tree().quit()
