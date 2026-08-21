extends Control

const MAX_NAME_LENGTH := 18
const SAFE_NAME := "^[a-zA-Z0-9 _.-]+$"
const MULTIPLAYER_WORLD := "res://scenes/gameplay/MultiplayerWorld.tscn"

const DIFFICULTIES := ["easy", "medium", "hard"]
const GAME_MODES := ["ai_uncle", "player_uncle"]
const DOGS := ["Milo", "Bean", "Rocket"]

@onready var panel: VBoxContainer = $Panel

var name_input: LineEdit
var room_code_input: LineEdit
var dog_select: OptionButton
var status_label: Label
var lobby_list: Label
var ready_button: Button
var start_button: Button
var difficulty_label: Label
var game_mode_label: Label
var volunteer_button: Button
var preview_pivot: Node3D

var player_name := ""
var pending_action := ""
var selected_difficulty := 1
var selected_game_mode := 0
var selected_dog := "Milo"
var player_ready := false
var uncle_volunteer := false

func _ready() -> void:
	_install_animated_background()
	_style_menu_shell()
	NetworkClient.connected.connect(_on_connected)
	NetworkClient.error_received.connect(_on_error_received)
	NetworkClient.room_joined.connect(_on_room_joined)
	NetworkClient.room_state_changed.connect(_on_room_state_changed)
	NetworkClient.match_started.connect(_on_match_started)
	_show_name_menu()

func _process(delta: float) -> void:
	if preview_pivot:
		preview_pivot.rotate_y(delta * 0.12)

func _show_name_menu() -> void:
	_clear_panel()
	_add_label("TINY PAWS", 48)
	_add_label("Small Dogs. Big House. Bad Idea.", 18)
	_add_spacer()
	_add_label("PLAYER NAME", 16)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Sumit"
	name_input.max_length = MAX_NAME_LENGTH
	name_input.text = _load_saved_name()
	_style_line_edit(name_input)
	panel.add_child(name_input)
	status_label = _add_label("", 16)
	_add_button("PLAY", _show_room_menu)
	_add_button("HOW TO PLAY", func() -> void: _set_status("Find keys, hide under giant furniture, rescue friends, then escape."))
	_add_button("SETTINGS", func() -> void: _set_status("Graphics presets are planned for the next performance pass."))
	_add_button("CREDITS", func() -> void: _set_status("Original Tiny Paws prototype with procedural in-project art."))

func _show_room_menu() -> void:
	player_name = _sanitize_name(name_input.text)
	if player_name.is_empty():
		_set_status("Use 1-18 letters, numbers, spaces, dots, dashes, or underscores.")
		return

	_save_name(player_name)
	_clear_panel()
	_add_label("TINY PAWS", 44)
	_add_label("MULTIPLAYER", 20)
	_add_spacer()
	_add_label("DOG SELECTION", 16)
	dog_select = OptionButton.new()
	for dog in DOGS:
		dog_select.add_item(dog)
	dog_select.item_selected.connect(_on_dog_selected)
	_style_option_button(dog_select)
	panel.add_child(dog_select)
	status_label = _add_label("", 16)
	_add_button("CREATE ROOM", _create_room)
	room_code_input = LineEdit.new()
	room_code_input.placeholder_text = "ROOM CODE"
	room_code_input.max_length = 4
	_style_line_edit(room_code_input)
	panel.add_child(room_code_input)
	_add_button("JOIN ROOM", _join_room)
	_add_button("BACK", _show_name_menu)

func _on_dog_selected(index: int) -> void:
	selected_dog = DOGS[index]

func _create_room() -> void:
	pending_action = "create"
	_connect_or_send_pending()

func _join_room() -> void:
	var join_code := room_code_input.text.strip_edges().to_upper()
	if join_code.length() != 4:
		_set_status("Enter a 4-character room code.")
		return
	pending_action = "join:%s" % join_code
	_connect_or_send_pending()

func _connect_or_send_pending() -> void:
	_set_status("Connecting...")
	if NetworkClient.is_open():
		_send_pending_action()
	else:
		NetworkClient.connect_to_server()

func _on_connected() -> void:
	_send_pending_action()

func _send_pending_action() -> void:
	if pending_action == "create":
		NetworkClient.create_room(player_name, selected_dog)
	elif pending_action.begins_with("join:"):
		NetworkClient.join_room(pending_action.trim_prefix("join:"), player_name, selected_dog)
	pending_action = ""

func _on_room_joined(room_code: String, _session_id: String) -> void:
	_show_lobby(room_code)

func _show_lobby(room_code: String) -> void:
	_clear_panel()
	_add_label("TINY PAWS", 42)
	_add_label("ROOM: %s" % room_code, 26)
	difficulty_label = _add_label("", 20)
	game_mode_label = _add_label("", 20)
	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(mode_row)
	var prev_mode := Button.new()
	prev_mode.text = "<"
	prev_mode.pressed.connect(_previous_game_mode)
	_style_small_button(prev_mode)
	mode_row.add_child(prev_mode)
	var next_mode := Button.new()
	next_mode.text = ">"
	next_mode.pressed.connect(_next_game_mode)
	_style_small_button(next_mode)
	mode_row.add_child(next_mode)
	var difficulty_row := HBoxContainer.new()
	difficulty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(difficulty_row)
	var prev := Button.new()
	prev.text = "<"
	prev.pressed.connect(_previous_difficulty)
	_style_small_button(prev)
	difficulty_row.add_child(prev)
	var next := Button.new()
	next.text = ">"
	next.pressed.connect(_next_difficulty)
	_style_small_button(next)
	difficulty_row.add_child(next)
	lobby_list = _add_label("", 18)
	volunteer_button = _add_button("I WANT TO PLAY UNCLE", _toggle_uncle_volunteer)
	ready_button = _add_button("READY", _toggle_ready)
	start_button = _add_button("START GAME", _start_game)
	status_label = _add_label("", 16)
	_update_lobby(NetworkClient.state)

func _on_room_state_changed(state: Dictionary) -> void:
	if lobby_list:
		_update_lobby(state)

func _update_lobby(state: Dictionary) -> void:
	if state.is_empty():
		return

	var difficulty := String(state.get("difficulty", "medium")).to_upper()
	difficulty_label.text = "DIFFICULTY: %s" % difficulty
	var game_mode := String(state.get("gameMode", "ai_uncle"))
	game_mode_label.text = "GAME MODE: %s" % game_mode.replace("_", " ").to_upper()
	if volunteer_button:
		volunteer_button.visible = game_mode == "player_uncle"
		volunteer_button.text = "UNCLE VOLUNTEER: YES" if uncle_volunteer else "I WANT TO PLAY UNCLE"
	var rows := PackedStringArray()
	rows.append("PLAYERS")
	for player in state.get("players", []):
		var status := "READY" if bool(player.get("ready", false)) else "NOT READY"
		var host_tag := " HOST" if bool(player.get("host", false)) else ""
		var role := String(player.get("role", "dog")).to_upper()
		rows.append("%s    %s    %s    %s%s" % [
			String(player.get("name", "Player")),
			String(player.get("dog", "Milo")),
			role,
			status,
			host_tag
		])
	lobby_list.text = "\n".join(rows)

	start_button.visible = NetworkClient.is_host()
	ready_button.text = "NOT READY" if player_ready else "READY"

func _toggle_ready() -> void:
	player_ready = not player_ready
	NetworkClient.set_ready(player_ready)
	ready_button.text = "NOT READY" if player_ready else "READY"

func _previous_difficulty() -> void:
	if not NetworkClient.is_host():
		return
	selected_difficulty = wrapi(selected_difficulty - 1, 0, DIFFICULTIES.size())
	NetworkClient.set_difficulty(DIFFICULTIES[selected_difficulty])

func _next_difficulty() -> void:
	if not NetworkClient.is_host():
		return
	selected_difficulty = wrapi(selected_difficulty + 1, 0, DIFFICULTIES.size())
	NetworkClient.set_difficulty(DIFFICULTIES[selected_difficulty])

func _previous_game_mode() -> void:
	if not NetworkClient.is_host():
		return
	selected_game_mode = wrapi(selected_game_mode - 1, 0, GAME_MODES.size())
	NetworkClient.set_game_mode(GAME_MODES[selected_game_mode])

func _next_game_mode() -> void:
	if not NetworkClient.is_host():
		return
	selected_game_mode = wrapi(selected_game_mode + 1, 0, GAME_MODES.size())
	NetworkClient.set_game_mode(GAME_MODES[selected_game_mode])

func _toggle_uncle_volunteer() -> void:
	uncle_volunteer = not uncle_volunteer
	NetworkClient.volunteer_uncle(uncle_volunteer)
	if volunteer_button:
		volunteer_button.text = "UNCLE VOLUNTEER: YES" if uncle_volunteer else "I WANT TO PLAY UNCLE"

func _start_game() -> void:
	NetworkClient.start_game()

func _on_match_started() -> void:
	get_tree().change_scene_to_file(MULTIPLAYER_WORLD)

func _on_error_received(code: String) -> void:
	_set_status(code.replace("_", " "))

func _add_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
	label.add_theme_color_override("font_shadow_color", Color(0.06, 0.03, 0.025, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return label

func _add_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 44)
	_style_button(button)
	button.pressed.connect(callback)
	panel.add_child(button)
	return button

func _add_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 12)
	panel.add_child(spacer)

func _clear_panel() -> void:
	for child in panel.get_children():
		child.queue_free()

func _set_status(message: String) -> void:
	if status_label:
		status_label.text = message

func _sanitize_name(raw_name: String) -> String:
	var trimmed := raw_name.strip_edges()
	while trimmed.contains("  "):
		trimmed = trimmed.replace("  ", " ")

	if trimmed.is_empty() or trimmed.length() > MAX_NAME_LENGTH:
		return ""

	var regex := RegEx.new()
	if regex.compile(SAFE_NAME) != OK:
		return ""

	return trimmed if regex.search(trimmed) != null else ""

func _load_saved_name() -> String:
	if not FileAccess.file_exists("user://player_name.txt"):
		return ""

	var file := FileAccess.open("user://player_name.txt", FileAccess.READ)
	return file.get_as_text().strip_edges() if file else ""

func _save_name(next_player_name: String) -> void:
	var file := FileAccess.open("user://player_name.txt", FileAccess.WRITE)
	if file:
		file.store_string(next_player_name)

func _install_animated_background() -> void:
	var background := $Background as ColorRect
	background.color = Color(0.02, 0.025, 0.035, 0.58)

	var container := SubViewportContainer.new()
	container.name = "AnimatedHousePreview"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	add_child(container)
	move_child(container, 0)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)

	preview_pivot = Node3D.new()
	preview_pivot.name = "PreviewPivot"
	viewport.add_child(preview_pivot)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 5.2, 12.5)
	camera.rotation_degrees = Vector3(-18, 0, 0)
	camera.fov = 48
	camera.current = true
	viewport.add_child(camera)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(0.60, 0.72, 1.0)
	viewport.add_child(sun)

	var warm := OmniLight3D.new()
	warm.position = Vector3(0, 3.5, 1.5)
	warm.light_energy = 2.0
	warm.omni_range = 9
	warm.light_color = Color(1.0, 0.63, 0.32)
	viewport.add_child(warm)

	_preview_box("PreviewFloor", Vector3(14, 0.2, 9), Vector3(0, -0.1, 0), Color(0.34, 0.22, 0.14))
	_preview_box("PreviewBackWall", Vector3(14, 4, 0.3), Vector3(0, 1.8, -4.5), Color(0.10, 0.44, 0.52))
	_preview_box("PreviewLeftWall", Vector3(0.3, 4, 9), Vector3(-7, 1.8, 0), Color(0.90, 0.42, 0.18))
	_preview_box("PreviewSofa", Vector3(4.2, 0.8, 1.3), Vector3(-2.6, 0.4, 1.1), Color(0.04, 0.42, 0.50))
	_preview_box("PreviewSofaBack", Vector3(4.4, 1.3, 0.3), Vector3(-2.6, 0.85, 1.8), Color(0.03, 0.30, 0.36))
	_preview_box("PreviewTable", Vector3(2.4, 0.25, 1.2), Vector3(1.8, 0.65, 0.5), Color(0.56, 0.30, 0.12))
	_preview_box("PreviewStairs", Vector3(2.8, 0.25, 0.7), Vector3(4.8, 0.2, -2.2), Color(0.42, 0.25, 0.12))
	for i in range(7):
		_preview_box("PreviewStep_%d" % i, Vector3(2.8, 0.2, 0.48), Vector3(4.8, 0.25 + i * 0.18, -2.2 - i * 0.48), Color(0.50, 0.29, 0.14))

func _style_menu_shell() -> void:
	panel.add_theme_constant_override("separation", 12)
	panel.custom_minimum_size = Vector2(460, 380)

func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _stylebox(Color(0.95, 0.42, 0.18), 12))
	button.add_theme_stylebox_override("hover", _stylebox(Color(1.0, 0.58, 0.24), 12))
	button.add_theme_stylebox_override("pressed", _stylebox(Color(0.70, 0.22, 0.12), 12))
	button.add_theme_color_override("font_color", Color(0.08, 0.04, 0.02))
	button.add_theme_font_size_override("font_size", 20)

func _style_small_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(48, 38)
	_style_button(button)

func _style_line_edit(line_edit: LineEdit) -> void:
	line_edit.custom_minimum_size = Vector2(260, 42)
	line_edit.add_theme_stylebox_override("normal", _stylebox(Color(0.08, 0.13, 0.18, 0.92), 10))
	line_edit.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
	line_edit.add_theme_color_override("caret_color", Color(1.0, 0.72, 0.28))
	line_edit.add_theme_font_size_override("font_size", 18)

func _style_option_button(option_button: OptionButton) -> void:
	option_button.custom_minimum_size = Vector2(260, 42)
	option_button.add_theme_stylebox_override("normal", _stylebox(Color(0.08, 0.13, 0.18, 0.92), 10))
	option_button.add_theme_stylebox_override("hover", _stylebox(Color(0.15, 0.30, 0.36, 0.95), 10))
	option_button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
	option_button.add_theme_font_size_override("font_size", 18)

func _stylebox(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _preview_box(node_name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	mesh_instance.material_override = material
	preview_pivot.add_child(mesh_instance)
