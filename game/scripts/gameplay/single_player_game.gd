extends Node3D

const HOUSE_BUILDER := preload("res://scripts/art/stylized_house_builder.gd")
const TOWN_BUILDER := preload("res://scripts/art/grumble_town_builder.gd")
const REQUIRED_KEYS := 3
const INTERACT_DISTANCE := 1.6

const KEY_SPAWNS := [
	{"id": "kitchen_counter", "label": "Kitchen Counter", "position": Vector3(-11.7, 1.18, -3.8)},
	{"id": "under_table", "label": "Under Dining Table", "position": Vector3(0.0, 0.42, -5.7)},
	{"id": "study_desk", "label": "Study Desk", "position": Vector3(11.5, 1.12, -4.8)},
	{"id": "garage_crate", "label": "Garage Crate", "position": Vector3(-12.8, 0.85, 5.2)},
	{"id": "guest_bedroom", "label": "Guest Bedroom Pillow", "position": Vector3(-10.8, 4.95, -8.5)},
	{"id": "security_room", "label": "Security Monitor", "position": Vector3(-10.0, 9.25, -9.6)}
]

@onready var player: CharacterBody3D = $Player
@onready var uncle_grumble: CharacterBody3D = $UncleGrumble

var collected_keys := 0
var exit_unlocked := false
var escaped := false
var captures := 0
var rescues_left := 2
var active_keys: Array[Node3D] = []
var exit_marker: Node3D
var hud_keys: Label
var hud_status: Label
var hud_prompt: Label
var hud_notice: Label
var notice_timer := 0.0

func _ready() -> void:
	randomize()
	_build_house()
	player.global_position = Vector3(0, 0.7, 32.0)
	_spawn_keys()
	_create_exit()
	_create_hud()
	_configure_neighbor()
	_update_hud()
	_show_notice("Find %d keys and escape Uncle Grumble's house." % REQUIRED_KEYS)

func _process(delta: float) -> void:
	if notice_timer > 0.0:
		notice_timer -= delta
		if notice_timer <= 0.0:
			hud_notice.text = ""

	if escaped:
		hud_prompt.text = "ESCAPED! Press Esc to release mouse."
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

	for index in range(REQUIRED_KEYS):
		var spawn = spawn_pool[index]
		var key := MeshInstance3D.new()
		key.name = "Key_%s" % spawn.id
		key.position = spawn.position
		key.set_meta("key_id", spawn.id)
		key.set_meta("label", spawn.label)

		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.12
		mesh.bottom_radius = 0.12
		mesh.height = 0.08
		key.mesh = mesh
		key.material_override = _material(Color(1.0, 0.78, 0.2))
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
		return "Exit locked. Find %d more key(s)." % (REQUIRED_KEYS - collected_keys)

	return ""

func _try_interact() -> void:
	var nearest_key := _nearest_key()
	if nearest_key:
		nearest_key.visible = false
		active_keys.erase(nearest_key)
		collected_keys += 1
		if collected_keys >= REQUIRED_KEYS:
			exit_unlocked = true
			_show_notice("THE EXIT CAN NOW BE UNLOCKED")
		else:
			_show_notice("Key found: %d / %d" % [collected_keys, REQUIRED_KEYS])
		_update_hud()
		return

	if exit_unlocked and player.global_position.distance_to(exit_marker.global_position) <= INTERACT_DISTANCE + 0.9:
		escaped = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_show_notice("ESCAPED! Tiny paws, huge victory.")

func _configure_neighbor() -> void:
	var patrol_points := [
		Vector3(0, 0.9, -5.8),
		Vector3(-12.0, 0.9, -6.5),
		Vector3(11.0, 0.9, -5.6),
		Vector3(-9.0, 0.9, 4.6),
		Vector3(6.0, 0.9, 5.8),
		Vector3(11.6, 0.9, 0.8)
	]
	uncle_grumble.call("configure", player, patrol_points)
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
		escaped = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_show_notice("ELIMINATED. Uncle Grumble finally got you.")
	else:
		rescues_left -= 1
		player.global_position = Vector3(0, 0.6, 6.8)
		uncle_grumble.global_position = Vector3(0, 0.9, -6.5)
		uncle_grumble.call("reset_patrol")
		_show_notice("CAPTURED! You slipped out of the cage. Rescues left: %d" % rescues_left)
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
	hud_keys.text = "KEYS: %d / %d" % [collected_keys, REQUIRED_KEYS]
	if hud_status:
		hud_status.text = "RESCUES LEFT: %d    CAPTURES: %d" % [rescues_left, captures]

func _show_notice(message: String) -> void:
	if hud_notice:
		hud_notice.text = message
	notice_timer = 4.0

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material
