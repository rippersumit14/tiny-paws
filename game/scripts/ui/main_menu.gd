extends Control

const MAX_NAME_LENGTH := 18
const SAFE_NAME := "^[a-zA-Z0-9 _.-]+$"
const TEST_WORLD := "res://scenes/gameplay/TestWorld.tscn"

@onready var name_input: LineEdit = $Panel/NameInput
@onready var status_label: Label = $Panel/StatusLabel
@onready var play_button: Button = $Panel/PlayButton

func _ready() -> void:
	name_input.text = _load_saved_name()
	play_button.pressed.connect(_on_play_pressed)

func _on_play_pressed() -> void:
	var player_name := _sanitize_name(name_input.text)
	if player_name.is_empty():
		status_label.text = "Use 1-18 letters, numbers, spaces, dots, dashes, or underscores."
		return

	_save_name(player_name)
	get_tree().change_scene_to_file(TEST_WORLD)

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

func _save_name(player_name: String) -> void:
	var file := FileAccess.open("user://player_name.txt", FileAccess.WRITE)
	if file:
		file.store_string(player_name)
