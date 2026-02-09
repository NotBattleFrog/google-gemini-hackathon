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
	
	# Style the SetupPanel and APIKeyInput to be opaque and visible
	_setup_panel_styling()


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

func _setup_panel_styling() -> void:
	# Make SetupPanel opaque with solid background
	if setup_panel:
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.15, 0.15, 0.2, 0.98)  # Dark, almost opaque
		panel_style.border_color = Color(0.4, 0.5, 0.7, 1.0)
		panel_style.border_width_left = 2
		panel_style.border_width_right = 2
		panel_style.border_width_top = 2
		panel_style.border_width_bottom = 2
		panel_style.corner_radius_top_left = 8
		panel_style.corner_radius_top_right = 8
		panel_style.corner_radius_bottom_left = 8
		panel_style.corner_radius_bottom_right = 8
		setup_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Make APIKeyInput opaque with solid background
	if api_key_input:
		var input_style = StyleBoxFlat.new()
		input_style.bg_color = Color(0.2, 0.2, 0.25, 1.0)  # Solid dark background
		input_style.border_color = Color(0.5, 0.5, 0.6, 1.0)
		input_style.border_width_left = 1
		input_style.border_width_right = 1
		input_style.border_width_top = 1
		input_style.border_width_bottom = 1
		input_style.corner_radius_top_left = 4
		input_style.corner_radius_top_right = 4
		input_style.corner_radius_bottom_left = 4
		input_style.corner_radius_bottom_right = 4
		api_key_input.add_theme_stylebox_override("normal", input_style)
		api_key_input.add_theme_stylebox_override("focus", input_style)
		
		# Ensure text is visible
		api_key_input.add_theme_color_override("font_color", Color.WHITE)
		api_key_input.add_theme_color_override("font_selected_color", Color.WHITE)
		api_key_input.add_theme_color_override("font_placeholder_color", Color(0.7, 0.7, 0.7, 1.0))
