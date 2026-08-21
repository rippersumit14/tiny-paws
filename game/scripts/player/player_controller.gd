extends CharacterBody3D

signal barked(world_position: Vector3, intensity: float)

@export var walk_speed := 4.2
@export var sprint_speed := 6.0
@export var acceleration := 12.0
@export var jump_velocity := 3.2
@export var mouse_sensitivity := 0.003

@onready var camera_pivot: Node3D = $CameraPivot
@onready var flashlight: SpotLight3D = $CameraPivot/SpringArm3D/Camera3D/Flashlight

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_pitch := -0.22
var leg_nodes: Array[Node3D] = []
var tail_node: Node3D
var inventory_open := false
var joint_items := 2
var edible_items := 1
var cigarette_items := 2
var squeak_toy_items := 1
var bone_items := 1
var boost_timer := 0.0
var edible_timer := 0.0
var calm_timer := 0.0
var boost_cooldown := 0.0
var item_use_timer := 0.0
var pending_item := ""
var item_use_locked := false
var inventory_layer: CanvasLayer
var inventory_panel: PanelContainer
var inventory_label: Label
var inventory_list: VBoxContainer
var inventory_buttons: Array[Button] = []
var selected_item_index := 0
var was_mouse_captured_before_inventory := false

const ITEM_IDS := ["joint", "cigarette", "edible", "squeak_toy", "bone"]

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_pivot.rotation.x = camera_pitch
	_build_stylized_dog()
	_build_inventory_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pitch = clamp(camera_pitch - event.relative.y * mouse_sensitivity, -1.0, 0.45)
		camera_pivot.rotation.x = camera_pitch

	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible

	if event.is_action_pressed("inventory"):
		_toggle_inventory()

	if inventory_open and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_select_inventory_item(0)
		elif event.keycode == KEY_2:
			_select_inventory_item(1)
		elif event.keycode == KEY_3:
			_select_inventory_item(2)
		elif event.keycode == KEY_4:
			_select_inventory_item(3)
		elif event.keycode == KEY_5:
			_select_inventory_item(4)
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_E:
			_use_selected_item()

func _physics_process(delta: float) -> void:
	if boost_timer > 0.0:
		boost_timer -= delta
	if edible_timer > 0.0:
		edible_timer -= delta
	if calm_timer > 0.0:
		calm_timer -= delta
	if boost_cooldown > 0.0:
		boost_cooldown -= delta
	if item_use_timer > 0.0:
		item_use_timer -= delta
		if item_use_timer <= 0.0:
			_finish_pending_item()
	if inventory_open:
		_refresh_inventory_label()

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed_bonus := 1.0
	if boost_timer > 0.0:
		speed_bonus = 1.32
	elif edible_timer > 0.0:
		speed_bonus = 1.20
	elif calm_timer > 0.0:
		speed_bonus = 1.12
	var target_speed := (sprint_speed if Input.is_action_pressed("sprint") else walk_speed) * speed_bonus
	if item_use_timer > 0.0:
		target_speed *= 0.55
	var target_velocity := direction * target_speed

	var current_acceleration := acceleration * (1.22 if calm_timer > 0.0 else 1.0)
	velocity.x = move_toward(velocity.x, target_velocity.x, current_acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, current_acceleration * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	move_and_slide()
	_animate_dog(delta, Vector2(velocity.x, velocity.z).length())

	if Input.is_action_just_pressed("bark"):
		barked.emit(global_position, 1.0)

	if global_position.y < -8.0:
		global_position = Vector3(0, 0.7, 32.0)
		velocity = Vector3.ZERO

func _build_stylized_dog() -> void:
	for node_name in ["Body", "Head"]:
		var old_node := get_node_or_null(node_name)
		if old_node:
			old_node.visible = false

	var model := Node3D.new()
	model.name = "MiloModel"
	add_child(model)

	var fur := _material(Color(0.88, 0.65, 0.43))
	var dark_fur := _material(Color(0.28, 0.18, 0.14))
	var nose := _material(Color(0.04, 0.035, 0.03))
	var eye := _material(Color(0.02, 0.018, 0.015))
	var collar := _material(Color(0.12, 0.55, 0.85))

	_add_sphere(model, "RoundPugTorso", Vector3(0, 0.22, 0.05), Vector3(0.46, 0.34, 0.62), fur)
	_add_sphere(model, "BigHead", Vector3(0, 0.55, -0.36), Vector3(0.42, 0.34, 0.38), fur)
	_add_sphere(model, "Muzzle", Vector3(0, 0.49, -0.68), Vector3(0.26, 0.16, 0.18), dark_fur)
	_add_sphere(model, "Nose", Vector3(0, 0.53, -0.82), Vector3(0.10, 0.07, 0.05), nose)
	_add_sphere(model, "LeftEye", Vector3(-0.15, 0.64, -0.68), Vector3(0.055, 0.055, 0.04), eye)
	_add_sphere(model, "RightEye", Vector3(0.15, 0.64, -0.68), Vector3(0.055, 0.055, 0.04), eye)
	_add_box(model, "LeftFloppyEar", Vector3(0.13, 0.30, 0.08), Vector3(-0.34, 0.53, -0.38), dark_fur)
	_add_box(model, "RightFloppyEar", Vector3(0.13, 0.30, 0.08), Vector3(0.34, 0.53, -0.38), dark_fur)
	_add_box(model, "Collar", Vector3(0.62, 0.08, 0.13), Vector3(0, 0.43, -0.10), collar)

	for x in [-0.25, 0.25]:
		for z in [-0.28, 0.36]:
			var leg := _add_cylinder(model, "Leg", 0.075, 0.38, Vector3(x, 0.03, z), fur)
			leg_nodes.append(leg)
			_add_sphere(model, "Paw", Vector3(x, -0.18, z - 0.03), Vector3(0.12, 0.06, 0.15), dark_fur)

	tail_node = _add_cylinder(model, "CurledTail", 0.055, 0.55, Vector3(0, 0.38, 0.67), fur)
	tail_node.rotation.x = PI / 2.0
	tail_node.rotation.z = 0.8

func _animate_dog(_delta: float, speed: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	var moving := speed > 0.15
	var stride: float = sin(time * (10.0 if Input.is_action_pressed("sprint") else 7.0)) * (0.55 if moving else 0.08)
	for i in range(leg_nodes.size()):
		leg_nodes[i].rotation.x = stride if i % 2 == 0 else -stride
	if tail_node:
		tail_node.rotation.z = 0.8 + sin(time * 8.0) * (0.35 if moving else 0.12)

func _build_inventory_ui() -> void:
	inventory_layer = CanvasLayer.new()
	inventory_layer.name = "QuickInventory"
	add_child(inventory_layer)

	inventory_panel = PanelContainer.new()
	inventory_panel.visible = false
	inventory_panel.position = Vector2(28, 120)
	inventory_panel.custom_minimum_size = Vector2(360, 310)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.12, 0.88)
	style.border_color = Color(1.0, 0.70, 0.28, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	inventory_panel.add_theme_stylebox_override("panel", style)
	inventory_layer.add_child(inventory_panel)

	inventory_list = VBoxContainer.new()
	inventory_list.add_theme_constant_override("separation", 8)
	inventory_panel.add_child(inventory_list)

	inventory_label = Label.new()
	inventory_label.add_theme_font_size_override("font_size", 18)
	inventory_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.76))
	inventory_list.add_child(inventory_label)

	for i in range(ITEM_IDS.size()):
		var button := Button.new()
		button.custom_minimum_size = Vector2(320, 42)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func(index := i) -> void:
			_select_inventory_item(index)
		)
		inventory_buttons.append(button)
		inventory_list.add_child(button)

	var use_hint := Label.new()
	use_hint.text = "Select with 1-5 or mouse. Press E/Enter to use."
	use_hint.add_theme_font_size_override("font_size", 14)
	use_hint.add_theme_color_override("font_color", Color(0.78, 0.86, 0.90))
	inventory_list.add_child(use_hint)
	_refresh_inventory_label()

func _toggle_inventory() -> void:
	inventory_open = not inventory_open
	if inventory_panel:
		inventory_panel.visible = inventory_open
	if inventory_open:
		was_mouse_captured_before_inventory = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif was_mouse_captured_before_inventory:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_inventory_label()

func set_item_use_locked(locked: bool) -> void:
	item_use_locked = locked
	if locked:
		pending_item = ""
		item_use_timer = 0.0
		if inventory_open:
			_toggle_inventory()

func _select_inventory_item(index: int) -> void:
	selected_item_index = clampi(index, 0, ITEM_IDS.size() - 1)
	_refresh_inventory_label()

func _use_selected_item() -> void:
	if selected_item_index < 0 or selected_item_index >= ITEM_IDS.size():
		return
	_queue_item_use(ITEM_IDS[selected_item_index])

func _queue_item_use(item_id: String) -> void:
	if item_use_locked or item_use_timer > 0.0 or boost_cooldown > 0.0:
		return
	match item_id:
		"joint":
			if joint_items <= 0 or boost_timer > 0.0:
				return
			joint_items -= 1
		"edible":
			if edible_items <= 0 or edible_timer > 0.0:
				return
			edible_items -= 1
		"cigarette":
			if cigarette_items <= 0 or calm_timer > 0.0:
				return
			cigarette_items -= 1
		"squeak_toy":
			if squeak_toy_items <= 0:
				return
			squeak_toy_items -= 1
		"bone":
			if bone_items <= 0:
				return
			bone_items -= 1
		_:
			return
	pending_item = item_id
	item_use_timer = 0.42
	_spawn_use_prop(item_id)
	_refresh_inventory_label()

func _finish_pending_item() -> void:
	if pending_item == "":
		return
	var item_id := pending_item
	pending_item = ""
	match item_id:
		"joint":
			boost_timer = 7.0
			boost_cooldown = 9.0
			_spawn_smoke_puffs(Color(0.75, 0.95, 0.90), 7)
			barked.emit(global_position, 0.45)
		"edible":
			edible_timer = 14.0
			boost_cooldown = 11.0
			_spawn_smoke_puffs(Color(1.0, 0.78, 0.34), 4)
		"cigarette":
			calm_timer = 9.0
			boost_cooldown = 7.0
			_spawn_smoke_puffs(Color(0.82, 0.84, 0.78), 5)
			barked.emit(global_position, 0.28)
		"squeak_toy":
			boost_cooldown = 3.0
			barked.emit(global_position + -global_transform.basis.z * 3.0, 1.15)
			_spawn_smoke_puffs(Color(0.95, 0.38, 0.44), 3)
		"bone":
			boost_cooldown = 4.0
			barked.emit(global_position + -global_transform.basis.z * 4.5, 0.85)
			_spawn_smoke_puffs(Color(0.95, 0.90, 0.72), 3)
	_refresh_inventory_label()

func _refresh_inventory_label() -> void:
	if not inventory_label:
		return
	var boost_line := "Ready"
	if item_use_timer > 0.0:
		boost_line = "Using %s..." % _item_name(pending_item)
	if boost_timer > 0.0:
		boost_line = "Joint speed: %.0fs" % boost_timer
	elif edible_timer > 0.0:
		boost_line = "Edible energy: %.0fs" % edible_timer
	elif calm_timer > 0.0:
		boost_line = "Cigarette focus: %.0fs" % calm_timer
	elif boost_cooldown > 0.0:
		boost_line = "Cooldown: %.0fs" % boost_cooldown
	inventory_label.text = "QUICK ITEMS\n%s" % boost_line
	for i in range(inventory_buttons.size()):
		var item_id: String = ITEM_IDS[i]
		var selected := i == selected_item_index
		var count := _item_count(item_id)
		inventory_buttons[i].text = "%s [%d] %s  x%d\n    %s" % [
			">" if selected else " ",
			i + 1,
			_item_name(item_id),
			count,
			_item_description(item_id)
		]
		_style_inventory_button(inventory_buttons[i], selected, count > 0)

func _item_count(item_id: String) -> int:
	match item_id:
		"joint":
			return joint_items
		"edible":
			return edible_items
		"cigarette":
			return cigarette_items
		"squeak_toy":
			return squeak_toy_items
		"bone":
			return bone_items
		_:
			return 0

func _item_name(item_id: String) -> String:
	match item_id:
		"joint":
			return "Fictional Joint"
		"edible":
			return "Cartoon Edible"
		"cigarette":
			return "Cartoon Cigarette"
		"squeak_toy":
			return "Squeak Toy"
		"bone":
			return "Throw Bone"
		_:
			return "Item"

func _item_description(item_id: String) -> String:
	match item_id:
		"joint":
			return "Short movement boost with smoke puffs."
		"edible":
			return "Longer energy boost for sprint escapes."
		"cigarette":
			return "Focus boost: steadier acceleration."
		"squeak_toy":
			return "Loud distraction in front of you."
		"bone":
			return "Throws a tempting noise farther away."
		_:
			return ""

func _style_inventory_button(button: Button, selected: bool, available: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.17, 0.20, 0.92) if available else Color(0.08, 0.08, 0.09, 0.84)
	style.border_color = Color(1.0, 0.76, 0.30, 1.0) if selected else Color(0.30, 0.42, 0.48, 0.75)
	style.set_border_width_all(2 if selected else 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.disabled = not available

func _spawn_use_prop(item_id: String) -> void:
	var prop := MeshInstance3D.new()
	prop.name = "UseProp_%s" % item_id
	prop.position = Vector3(0, 0.55, -0.72)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.34, 0.08, 0.12)
	if item_id == "edible":
		mesh.size = Vector3(0.22, 0.16, 0.22)
	elif item_id == "bone":
		mesh.size = Vector3(0.48, 0.12, 0.16)
	prop.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = _item_color(item_id)
	material.roughness = 0.8
	prop.material_override = material
	add_child(prop)
	var tween := create_tween()
	tween.tween_property(prop, "position:y", 0.78, 0.2)
	tween.tween_property(prop, "scale", Vector3(0.2, 0.2, 0.2), 0.22)
	tween.tween_callback(Callable(prop, "queue_free"))

func _item_color(item_id: String) -> Color:
	match item_id:
		"joint":
			return Color(0.80, 0.95, 0.78)
		"edible":
			return Color(1.0, 0.65, 0.25)
		"cigarette":
			return Color(0.92, 0.90, 0.78)
		"squeak_toy":
			return Color(0.95, 0.25, 0.32)
		"bone":
			return Color(0.92, 0.84, 0.62)
		_:
			return Color.WHITE

func _spawn_smoke_puffs(color: Color, count: int) -> void:
	for i in range(count):
		var puff := MeshInstance3D.new()
		puff.name = "CartoonSmokePuff"
		puff.position = Vector3(
			randf_range(-0.32, 0.32),
			0.72 + randf_range(0.0, 0.35),
			randf_range(-0.42, -0.18)
		)
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(0.08, 0.16)
		mesh.height = mesh.radius * 2.0
		puff.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		puff.material_override = material
		add_child(puff)
		var tween := create_tween()
		tween.tween_property(puff, "position:y", puff.position.y + randf_range(0.35, 0.65), 0.8)
		tween.parallel().tween_property(puff, "scale", Vector3(1.8, 1.8, 1.8), 0.8)
		tween.tween_callback(Callable(puff, "queue_free"))

func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _add_sphere(parent: Node3D, node_name: String, position: Vector3, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.scale = scale_value
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
