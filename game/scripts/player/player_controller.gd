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
var calm_timer := 0.0
var boost_cooldown := 0.0
var inventory_layer: CanvasLayer
var inventory_panel: PanelContainer
var inventory_label: Label

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
			_use_joint_item()
		elif event.keycode == KEY_2:
			_use_edible_item()
		elif event.keycode == KEY_3:
			_use_cigarette_item()
		elif event.keycode == KEY_4:
			_use_squeak_toy()
		elif event.keycode == KEY_5:
			_use_bone()

func _physics_process(delta: float) -> void:
	if boost_timer > 0.0:
		boost_timer -= delta
	if calm_timer > 0.0:
		calm_timer -= delta
	if boost_cooldown > 0.0:
		boost_cooldown -= delta
	if inventory_open:
		_refresh_inventory_label()

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed_bonus := 1.0
	if boost_timer > 0.0:
		speed_bonus = 1.32
	elif calm_timer > 0.0:
		speed_bonus = 1.12
	var target_speed := (sprint_speed if Input.is_action_pressed("sprint") else walk_speed) * speed_bonus
	var target_velocity := direction * target_speed

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

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
	inventory_panel.custom_minimum_size = Vector2(270, 190)
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

	inventory_label = Label.new()
	inventory_label.add_theme_font_size_override("font_size", 18)
	inventory_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.76))
	inventory_panel.add_child(inventory_label)
	_refresh_inventory_label()

func _toggle_inventory() -> void:
	inventory_open = not inventory_open
	if inventory_panel:
		inventory_panel.visible = inventory_open
	_refresh_inventory_label()

func _use_joint_item() -> void:
	if joint_items <= 0 or boost_cooldown > 0.0:
		return
	joint_items -= 1
	boost_timer = 7.0
	boost_cooldown = 10.0
	_spawn_smoke_puffs(Color(0.75, 0.95, 0.90), 7)
	barked.emit(global_position, 0.45)
	_refresh_inventory_label()

func _use_edible_item() -> void:
	if edible_items <= 0 or boost_cooldown > 0.0:
		return
	edible_items -= 1
	boost_timer = 11.0
	boost_cooldown = 12.0
	_spawn_smoke_puffs(Color(1.0, 0.78, 0.34), 4)
	_refresh_inventory_label()

func _use_cigarette_item() -> void:
	if cigarette_items <= 0 or boost_cooldown > 0.0:
		return
	cigarette_items -= 1
	calm_timer = 9.0
	boost_cooldown = 8.0
	_spawn_smoke_puffs(Color(0.82, 0.84, 0.78), 5)
	barked.emit(global_position, 0.28)
	_refresh_inventory_label()

func _use_squeak_toy() -> void:
	if squeak_toy_items <= 0 or boost_cooldown > 0.0:
		return
	squeak_toy_items -= 1
	boost_cooldown = 4.0
	barked.emit(global_position + -global_transform.basis.z * 3.0, 1.15)
	_spawn_smoke_puffs(Color(0.95, 0.38, 0.44), 3)
	_refresh_inventory_label()

func _use_bone() -> void:
	if bone_items <= 0 or boost_cooldown > 0.0:
		return
	bone_items -= 1
	boost_cooldown = 5.0
	barked.emit(global_position + -global_transform.basis.z * 4.5, 0.85)
	_spawn_smoke_puffs(Color(0.95, 0.90, 0.72), 3)
	_refresh_inventory_label()

func _refresh_inventory_label() -> void:
	if not inventory_label:
		return
	var boost_line := "Boost ready"
	if boost_timer > 0.0:
		boost_line = "Cartoon boost active: %.0fs" % boost_timer
	elif calm_timer > 0.0:
		boost_line = "Cartoon smoke focus: %.0fs" % calm_timer
	elif boost_cooldown > 0.0:
		boost_line = "Cooldown: %.0fs" % boost_cooldown
	inventory_label.text = "INVENTORY\n\n1  Fictional Joint x%d\n2  Cartoon Edible x%d\n3  Cartoon Cigarette x%d\n4  Squeak Toy x%d\n5  Throw Bone x%d\n\n%s" % [
		joint_items,
		edible_items,
		cigarette_items,
		squeak_toy_items,
		bone_items,
		boost_line
	]

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
