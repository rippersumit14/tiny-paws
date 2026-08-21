extends Node3D

const HOUSE_BUILDER := preload("res://scripts/art/stylized_house_builder.gd")
const TOWN_BUILDER := preload("res://scripts/art/grumble_town_builder.gd")
const INTERACT_DISTANCE := 1.6
const CAGE_ESCAPE_SECONDS := 2.6

const KEY_SPAWNS := [
	{"id": "kitchen_counter", "label": "Kitchen Counter", "position": Vector3(-11.7, 1.18, -3.8)},
	{"id": "under_table", "label": "Under Dining Table", "position": Vector3(0.0, 0.42, -5.7)},
	{"id": "study_desk", "label": "Study Desk", "position": Vector3(11.5, 1.12, -4.8)},
	{"id": "garage_crate", "label": "Garage Crate", "position": Vector3(-12.8, 0.85, 5.2)},
	{"id": "guest_bedroom", "label": "Guest Bedroom Pillow", "position": Vector3(-10.8, 4.95, -8.5)},
	{"id": "security_room", "label": "Security Monitor", "position": Vector3(-10.0, 9.25, -9.6)},
	{"id": "attic_trunk", "label": "Attic Trunk", "position": Vector3(10.4, 9.25, 7.6)},
	{"id": "basement_pipe", "label": "Basement Pipe Shelf", "position": Vector3(-4.0, 0.95, 7.8)}
]

@onready var player: CharacterBody3D = $Player
@onready var uncle_grumble: CharacterBody3D = $UncleGrumble

var collected_keys := 0
var required_keys := 3
var golden_key_required := false
var golden_key_collected := false
var exit_unlocked := false
var escaped := false
var caught_for_good := false
var captured := false
var captures := 0
var rescues_left := 2
var cage_escape_progress := 0.0
var selected_dog := "Milo"
var selected_difficulty := "medium"
var active_keys: Array[Node3D] = []
var exit_marker: Node3D
var hud_keys: Label
var hud_status: Label
var hud_prompt: Label
var hud_notice: Label
var result_layer: CanvasLayer
var result_panel: PanelContainer
var result_label: Label
var notice_timer := 0.0
var match_started_at := 0.0

func _ready() -> void:
	randomize()
	_load_single_player_config()
	_apply_solo_difficulty()
	_build_house()
	player.global_position = Vector3(0, 0.7, 32.0)
	_spawn_keys()
	_create_exit()
	_create_hud()
	_configure_neighbor()
	_update_hud()
	match_started_at = Time.get_ticks_msec() / 1000.0
	_show_notice("%s starts outside at night. Find the keys and escape Uncle Grumble's house." % selected_dog)

func _process(delta: float) -> void:
	if notice_timer > 0.0:
		notice_timer -= delta
		if notice_timer <= 0.0:
			hud_notice.text = ""

	if escaped or caught_for_good:
		hud_prompt.text = "ESCAPED! Press Esc to release mouse."
		return

	if captured:
		if Input.is_action_pressed("interact"):
			cage_escape_progress = minf(CAGE_ESCAPE_SECONDS, cage_escape_progress + delta)
			hud_prompt.text = "Hold E to squeeze through the dog gap: %d%%" % int((cage_escape_progress / CAGE_ESCAPE_SECONDS) * 100.0)
			if cage_escape_progress >= CAGE_ESCAPE_SECONDS:
				_escape_cage()
		else:
			cage_escape_progress = maxf(0.0, cage_escape_progress - delta * 0.8)
			hud_prompt.text = "Captured! Hold E near the weak cage gap to escape."
		return

	var prompt := _current_prompt()
	hud_prompt.text = prompt

	if prompt != "" and Input.is_action_just_pressed("interact"):
		_try_interact()

func _build_house() -> void:
	var town_builder := TOWN_BUILDER.new()
	town_builder.build(self)
	var builder := HOUSE_BUILDER.new()
	builder.build(self)
	_add_box("CaptureCageBase", Vector3(2.6, 0.12, 2.6), Vector3(0, 0.08, 7.4), Color(0.10, 0.11, 0.12), false)
	for x in [-1.2, -0.6, 0.0, 0.6, 1.2]:
		_add_box("CaptureCageBar_%s" % x, Vector3(0.08, 1.8, 0.08), Vector3(x, 0.95, 6.15), Color(0.05, 0.06, 0.07), false)

func _add_box(node_name: String, size: Vector3, position: Vector3, color: Color, collision := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	add_child(body)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	body.add_child(mesh)

	if collision:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)

	return body

func _add_furniture(node_name: String, size: Vector3, position: Vector3, color: Color, collision := true) -> void:
	_add_box(node_name, size, position, color, collision)

func _create_stairs() -> void:
	pass

func _spawn_keys() -> void:
	var spawn_pool := KEY_SPAWNS.duplicate()
	spawn_pool.shuffle()

	for index in range(required_keys):
		var spawn = spawn_pool[index]
		_add_key(spawn, false)

	if golden_key_required:
		_add_key({"id": "golden_attic_key", "label": "Golden Attic Key", "position": Vector3(10.4, 9.25, 7.6)}, true)

func _add_key(spawn: Dictionary, golden: bool) -> void:
	var key := MeshInstance3D.new()
	key.name = "Key_%s" % spawn.id
	key.position = spawn.position
	key.set_meta("key_id", spawn.id)
	key.set_meta("label", spawn.label)
	key.set_meta("golden", golden)

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.12 if not golden else 0.16
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.08
	key.mesh = mesh
	key.material_override = _material(Color(1.0, 0.78, 0.2) if not golden else Color(1.0, 0.92, 0.25))
	add_child(key)
	active_keys.append(key)

func _create_exit() -> void:
	exit_marker = _add_box("Front Exit", Vector3(2.8, 3.2, 0.18), Vector3(0, 1.5, 8.86), Color(0.2, 0.1, 0.06), false)
	exit_marker.set_meta("label", "Front Exit")

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	hud_keys = Label.new()
	hud_keys.position = Vector2(24, 22)
	hud_keys.add_theme_font_size_override("font_size", 24)
	layer.add_child(hud_keys)

	hud_notice = Label.new()
	hud_notice.position = Vector2(24, 90)
	hud_notice.add_theme_font_size_override("font_size", 20)
	layer.add_child(hud_notice)

	hud_status = Label.new()
	hud_status.position = Vector2(24, 56)
	hud_status.add_theme_font_size_override("font_size", 20)
	layer.add_child(hud_status)

	hud_prompt = Label.new()
	hud_prompt.position = Vector2(24, 650)
	hud_prompt.add_theme_font_size_override("font_size", 22)
	layer.add_child(hud_prompt)

func _current_prompt() -> String:
	var nearest_key := _nearest_key()
	if nearest_key:
		return "Press E to collect key: %s" % nearest_key.get_meta("label")

	if player.global_position.distance_to(exit_marker.global_position) <= INTERACT_DISTANCE + 0.9:
		if exit_unlocked:
			return "Press E to escape"
		var remaining: int = maxi(0, required_keys - collected_keys)
		if golden_key_required and not golden_key_collected:
			return "Exit locked. Find %d key(s) and the Golden Key." % remaining
		return "Exit locked. Find %d more key(s)." % remaining

	return ""

func _try_interact() -> void:
	var nearest_key := _nearest_key()
	if nearest_key:
		nearest_key.visible = false
		active_keys.erase(nearest_key)
		if bool(nearest_key.get_meta("golden", false)):
			golden_key_collected = true
			_show_notice("Golden Key found. Uncle will search harder.")
			uncle_grumble.call("hear_noise", player.global_position, 0.75)
		else:
			collected_keys += 1
		if _all_keys_ready():
			exit_unlocked = true
			_show_notice("THE EXIT CAN NOW BE UNLOCKED")
		else:
			_show_notice("Key found: %d / %d" % [collected_keys, required_keys])
		_update_hud()
		return

	if exit_unlocked and player.global_position.distance_to(exit_marker.global_position) <= INTERACT_DISTANCE + 0.9:
		escaped = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_show_notice("ESCAPED! Tiny paws, huge victory.")
		_show_result("ESCAPED", "Time: %.0fs\nKeys: %d\nCaptures: %d" % [
			(Time.get_ticks_msec() / 1000.0) - match_started_at,
			collected_keys,
			captures
		])

func _configure_neighbor() -> void:
	var patrol_routes := [
		[
			Vector3(0, 0.9, -5.8),
			Vector3(-12.0, 0.9, -6.5),
			Vector3(11.0, 0.9, -5.6),
			Vector3(6.0, 0.9, 5.8)
		],
		[
			Vector3(-8.5, 0.9, 4.2),
			Vector3(-1.8, 0.9, 7.4),
			Vector3(7.0, 0.9, 5.8),
			Vector3(11.6, 0.9, 0.8)
		],
		[
			Vector3(-10.0, 4.9, -7.4),
			Vector3(8.5, 4.9, -7.0),
			Vector3(9.2, 4.9, 7.0),
			Vector3(-9.5, 4.9, 7.0)
		],
		[
			Vector3(-12.0, 0.9, 24.0),
			Vector3(0, 0.9, 16.0),
			Vector3(12.0, 0.9, 24.0),
			Vector3(0, 0.9, 8.0)
		]
	]
	uncle_grumble.call("configure", player, patrol_routes[0])
	uncle_grumble.call("configure_routes", patrol_routes)
	uncle_grumble.call("configure_solo_difficulty", selected_difficulty)
	uncle_grumble.connect("player_captured", _on_player_captured)
	if player.has_signal("barked"):
		player.connect("barked", _on_player_barked)

func _on_player_barked(world_position: Vector3, intensity: float) -> void:
	uncle_grumble.call("hear_noise", world_position, intensity)
	_show_notice("BARK! Uncle Grumble heard something.")

func _on_player_captured() -> void:
	if escaped:
		return

	captures += 1
	if rescues_left <= 0:
		caught_for_good = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_show_notice("CAUGHT FOR GOOD")
		_show_result("CAUGHT FOR GOOD", "Uncle Grumble finally got you.\nKeys: %d / %d\nCaptures: %d" % [
			collected_keys,
			required_keys,
			captures
		])
	else:
		rescues_left -= 1
		captured = true
		cage_escape_progress = 0.0
		player.global_position = Vector3(0, 0.7, 6.8)
		player.velocity = Vector3.ZERO
		uncle_grumble.global_position = Vector3(0, 0.9, -6.5)
		uncle_grumble.call("guard_at", Vector3(0, 0.9, 2.8), 4.0)
		_show_notice("CAPTURED! Hold E to squeeze through the dog-only cage gap.")
	_update_hud()

func _escape_cage() -> void:
	captured = false
	cage_escape_progress = 0.0
	player.global_position = Vector3(1.8, 0.7, 7.8)
	player.velocity = Vector3.ZERO
	uncle_grumble.call("reset_patrol")
	_show_notice("You squeezed out. Rescues left: %d" % rescues_left)
	_update_hud()

func _nearest_key() -> Node3D:
	var best_key: Node3D = null
	var best_distance := INF

	for key in active_keys:
		if not key.visible:
			continue
		var distance := player.global_position.distance_to(key.global_position)
		if distance < INTERACT_DISTANCE and distance < best_distance:
			best_key = key
			best_distance = distance

	return best_key

func _update_hud() -> void:
	var golden_text := "    GOLDEN: %s" % ("YES" if golden_key_collected else "NO") if golden_key_required else ""
	hud_keys.text = "KEYS: %d / %d%s" % [collected_keys, required_keys, golden_text]
	if hud_status:
		hud_status.text = "DOG: %s    DIFFICULTY: %s    RESCUES LEFT: %d    CAPTURES: %d" % [
			selected_dog,
			selected_difficulty.to_upper(),
			rescues_left,
			captures
		]

func _show_notice(message: String) -> void:
	if hud_notice:
		hud_notice.text = message
	notice_timer = 4.0

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material

func _load_single_player_config() -> void:
	if not FileAccess.file_exists("user://single_player_config.json"):
		return
	var file := FileAccess.open("user://single_player_config.json", FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	selected_dog = String(parsed.get("dog", selected_dog))
	selected_difficulty = String(parsed.get("difficulty", selected_difficulty))

func _apply_solo_difficulty() -> void:
	match selected_difficulty:
		"easy":
			required_keys = 2
			golden_key_required = false
			if player:
				player.walk_speed = 4.5
				player.sprint_speed = 6.6
		"hard":
			required_keys = 3
			golden_key_required = true
			if player:
				player.walk_speed = 4.0
				player.sprint_speed = 5.8
		_:
			required_keys = 3
			golden_key_required = false

func _all_keys_ready() -> bool:
	return collected_keys >= required_keys and (not golden_key_required or golden_key_collected)

func _show_result(title: String, details: String) -> void:
	if result_layer:
		result_layer.queue_free()
	result_layer = CanvasLayer.new()
	result_layer.name = "SoloResult"
	add_child(result_layer)

	result_panel = PanelContainer.new()
	result_panel.position = Vector2(420, 180)
	result_panel.custom_minimum_size = Vector2(440, 300)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.06, 0.09, 0.94)
	style.border_color = Color(1.0, 0.68, 0.28, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	result_panel.add_theme_stylebox_override("panel", style)
	result_layer.add_child(result_panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	result_panel.add_child(column)

	result_label = Label.new()
	result_label.text = "%s\n\n%s" % [title, details]
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 26)
	result_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
	column.add_child(result_label)

	var retry := Button.new()
	retry.text = "RETRY"
	retry.pressed.connect(func() -> void: get_tree().reload_current_scene())
	column.add_child(retry)

	var main_menu := Button.new()
	main_menu.text = "MAIN MENU"
	main_menu.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/ui/Main.tscn"))
	column.add_child(main_menu)
