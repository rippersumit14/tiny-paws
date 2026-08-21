extends Node3D

const REQUIRED_KEYS := 3
const INTERACT_DISTANCE := 1.6

const KEY_SPAWNS := [
	{"id": "kitchen_counter", "label": "Kitchen Counter", "position": Vector3(-6.2, 1.2, -3.2)},
	{"id": "under_table", "label": "Under Dining Table", "position": Vector3(-2.5, 0.35, -4.3)},
	{"id": "study_desk", "label": "Study Desk", "position": Vector3(6.4, 1.05, -3.8)},
	{"id": "garage_crate", "label": "Garage Crate", "position": Vector3(-7.4, 0.65, 4.8)},
	{"id": "bedroom_corner", "label": "Bedroom Corner", "position": Vector3(3.8, 0.4, 7.3)},
	{"id": "bathroom_shelf", "label": "Bathroom Shelf", "position": Vector3(6.2, 1.35, 7.6)}
]

@onready var player: CharacterBody3D = $Player

var collected_keys := 0
var exit_unlocked := false
var escaped := false
var active_keys: Array[Node3D] = []
var exit_marker: Node3D
var hud_keys: Label
var hud_prompt: Label
var hud_notice: Label
var notice_timer := 0.0

func _ready() -> void:
	randomize()
	_build_house()
	_spawn_keys()
	_create_exit()
	_create_hud()
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
	_add_box("Ground Floor", Vector3(22, 0.25, 18), Vector3(0, -0.12, 0), Color(0.28, 0.24, 0.2))
	_add_box("Upper Floor", Vector3(18, 0.25, 13), Vector3(1.5, 4.0, 2.5), Color(0.24, 0.22, 0.24))

	# Outer walls leave a large front doorway at z = 8.6.
	_add_box("Back Wall", Vector3(22, 4, 0.35), Vector3(0, 1.9, -9), Color(0.38, 0.34, 0.32))
	_add_box("Left Wall", Vector3(0.35, 4, 18), Vector3(-11, 1.9, 0), Color(0.38, 0.34, 0.32))
	_add_box("Right Wall", Vector3(0.35, 4, 18), Vector3(11, 1.9, 0), Color(0.38, 0.34, 0.32))
	_add_box("Front Wall Left", Vector3(8, 4, 0.35), Vector3(-7, 1.9, 9), Color(0.38, 0.34, 0.32))
	_add_box("Front Wall Right", Vector3(8, 4, 0.35), Vector3(7, 1.9, 9), Color(0.38, 0.34, 0.32))

	_add_box("Kitchen Divider", Vector3(0.28, 2.6, 7), Vector3(-4.2, 1.25, -4.8), Color(0.32, 0.29, 0.28))
	_add_box("Study Divider", Vector3(0.28, 2.6, 7), Vector3(4.2, 1.25, -4.8), Color(0.32, 0.29, 0.28))
	_add_box("Hall Divider", Vector3(12, 2.6, 0.28), Vector3(0, 1.25, 2.2), Color(0.32, 0.29, 0.28))

	_add_furniture("Giant Couch", Vector3(4.4, 1.2, 1.5), Vector3(-4.2, 0.55, 1.2), Color(0.14, 0.34, 0.42))
	_add_furniture("Dining Table", Vector3(3.2, 0.25, 2.2), Vector3(-2.5, 1.0, -4.3), Color(0.34, 0.2, 0.12))
	_add_furniture("Kitchen Counter", Vector3(4.4, 1.2, 1.0), Vector3(-7.0, 0.55, -3.2), Color(0.44, 0.42, 0.38))
	_add_furniture("Study Desk", Vector3(3.3, 1.0, 1.2), Vector3(6.6, 0.5, -3.8), Color(0.28, 0.18, 0.12))
	_add_furniture("Garage Crates", Vector3(2.2, 1.2, 2.2), Vector3(-7.5, 0.55, 5.0), Color(0.37, 0.24, 0.12))
	_add_furniture("Huge Bed", Vector3(4.0, 0.85, 3.0), Vector3(2.8, 0.38, 7.0), Color(0.48, 0.2, 0.28))
	_add_furniture("Bathroom Shelf", Vector3(2.4, 1.6, 0.7), Vector3(6.2, 0.75, 7.8), Color(0.64, 0.66, 0.62))
	_add_furniture("Uncle Cage", Vector3(2.0, 1.8, 2.0), Vector3(0, 0.85, 6.8), Color(0.12, 0.12, 0.14), false)

	_create_stairs()

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
	for step_index in range(8):
		var step_size := Vector3(2.2, 0.28, 0.65)
		var step_pos := Vector3(8.0, 0.14 + step_index * 0.26, 0.5 + step_index * 0.55)
		_add_box("Stair %02d" % step_index, step_size, step_pos, Color(0.31, 0.22, 0.16))

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
	hud_notice.position = Vector2(24, 58)
	hud_notice.add_theme_font_size_override("font_size", 20)
	layer.add_child(hud_notice)

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

func _show_notice(message: String) -> void:
	if hud_notice:
		hud_notice.text = message
	notice_timer = 4.0

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material
