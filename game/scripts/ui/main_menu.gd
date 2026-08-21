extends Control

const MAX_NAME_LENGTH := 18
const SAFE_NAME := "^[a-zA-Z0-9 _.-]+$"
const MULTIPLAYER_WORLD := "res://scenes/gameplay/MultiplayerWorld.tscn"

const DIFFICULTIES := ["easy", "medium", "hard"]

@onready var panel: VBoxContainer = $Panel

var name_input: LineEdit
var room_code_input: LineEdit
var status_label: Label
var lobby_list: Label
var ready_button: Button
var start_button: Button
var difficulty_label: Label

var player_name := ""
var pending_action := ""
var selected_difficulty := 1
var player_ready := false

func _ready() -> void:
	NetworkClient.connected.connect(_on_connected)
	NetworkClient.error_received.connect(_on_error_received)
	NetworkClient.room_joined.connect(_on_room_joined)
	NetworkClient.room_state_changed.connect(_on_room_state_changed)
	NetworkClient.match_started.connect(_on_match_started)
	_show_name_menu()

func _show_name_menu() -> void:
	_clear_panel()
	_add_label("TINY PAWS", 48)
	_add_label("Cute dogs. Creepy house. Bad decisions.", 18)
	_add_spacer()
	_add_label("PLAYER NAME", 16)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Sumit"
	name_input.max_length = MAX_NAME_LENGTH
	name_input.text = _load_saved_name()
	panel.add_child(name_input)
	status_label = _add_label("", 16)
	_add_button("PLAY", _show_room_menu)
	_add_button("SETTINGS", func() -> void: _set_status("Settings coming after multiplayer is playable."))
	_add_button("CREDITS", func() -> void: _set_status("Original Tiny Paws prototype. No third-party assets yet."))

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
	status_label = _add_label("", 16)
	_add_button("CREATE ROOM", _create_room)
	room_code_input = LineEdit.new()
	room_code_input.placeholder_text = "ROOM CODE"
	room_code_input.max_length = 4
	panel.add_child(room_code_input)
	_add_button("JOIN ROOM", _join_room)
	_add_button("BACK", _show_name_menu)

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
		NetworkClient.create_room(player_name, "Milo")
	elif pending_action.begins_with("join:"):
		NetworkClient.join_room(pending_action.trim_prefix("join:"), player_name, "Milo")
	pending_action = ""

func _on_room_joined(room_code: String, _session_id: String) -> void:
	_show_lobby(room_code)

func _show_lobby(room_code: String) -> void:
	_clear_panel()
	_add_label("TINY PAWS", 42)
	_add_label("ROOM: %s" % room_code, 26)
	difficulty_label = _add_label("", 20)
	var difficulty_row := HBoxContainer.new()
	difficulty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(difficulty_row)
	var prev := Button.new()
	prev.text = "<"
	prev.pressed.connect(_previous_difficulty)
	difficulty_row.add_child(prev)
	var next := Button.new()
	next.text = ">"
	next.pressed.connect(_next_difficulty)
	difficulty_row.add_child(next)
	lobby_list = _add_label("", 18)
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
	var rows := PackedStringArray()
	rows.append("PLAYERS")
	for player in state.get("players", []):
		var status := "READY" if bool(player.get("ready", false)) else "NOT READY"
		var host_tag := " HOST" if bool(player.get("host", false)) else ""
		rows.append("%s    %s    %s%s" % [
			String(player.get("name", "Player")),
			String(player.get("dog", "Milo")),
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
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return label

func _add_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
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
