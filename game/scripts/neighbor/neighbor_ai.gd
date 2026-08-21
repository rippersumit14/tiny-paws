extends CharacterBody3D

signal player_captured

enum State {
	PATROL,
	SUSPICIOUS,
	INVESTIGATE,
	CHASE,
	SEARCH,
	GUARD,
	RETURN_TO_PATROL
}

@export var patrol_speed := 2.0
@export var chase_speed := 3.4
@export var vision_distance := 7.5
@export var field_of_view_degrees := 95.0
@export var capture_distance := 0.85
@export var search_duration := 2.2
@export var hearing_sensitivity := 1.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target_player: CharacterBody3D
var patrol_points: Array[Vector3] = []
var patrol_routes: Array[Array] = []
var patrol_index := 0
var route_index := 0
var state := State.PATROL
var investigation_point := Vector3.ZERO
var last_seen_position := Vector3.ZERO
var last_seen_direction := Vector3.ZERO
var search_timer := 0.0
var capture_cooldown := 0.0
var guard_timer := 0.0
var suspicion_memory: Dictionary = {}
var arm_nodes: Array[Node3D] = []
var leg_nodes: Array[Node3D] = []

func configure(player: CharacterBody3D, points: Array) -> void:
	target_player = player
	patrol_points.clear()
	for point in points:
		if point is Vector3:
			patrol_points.append(point)
	if patrol_points.is_empty():
		patrol_points.append(global_position)

func _ready() -> void:
	_build_uncle_model()

func configure_routes(routes: Array) -> void:
	patrol_routes.clear()
	for route in routes:
		if route is Array and not route.is_empty():
			patrol_routes.append(route)
	if not patrol_routes.is_empty():
		_apply_route(0)

func configure_solo_difficulty(difficulty: String) -> void:
	match difficulty:
		"easy":
			patrol_speed = 1.55
			chase_speed = 2.75
			vision_distance = 5.8
			field_of_view_degrees = 82.0
			search_duration = 1.45
			hearing_sensitivity = 0.68
		"hard":
			patrol_speed = 2.35
			chase_speed = 4.15
			vision_distance = 9.4
			field_of_view_degrees = 108.0
			search_duration = 3.7
			hearing_sensitivity = 1.35
		_:
			patrol_speed = 2.0
			chase_speed = 3.4
			vision_distance = 7.5
			field_of_view_degrees = 95.0
			search_duration = 2.2
			hearing_sensitivity = 1.0

func reset_patrol() -> void:
	state = State.RETURN_TO_PATROL
	capture_cooldown = 1.5

func guard_at(world_position: Vector3, duration: float) -> void:
	investigation_point = world_position
	guard_timer = maxf(duration, 0.5)
	state = State.GUARD
	capture_cooldown = maxf(capture_cooldown, 2.0)

func hear_noise(world_position: Vector3, intensity: float) -> void:
	if state == State.CHASE:
		return
	var radius: float = 10.0 * maxf(intensity, 0.2) * hearing_sensitivity
	if global_position.distance_to(world_position) <= radius:
		_remember_suspicion(world_position, intensity)
		investigation_point = world_position
		state = State.SUSPICIOUS

func _physics_process(delta: float) -> void:
	if not target_player:
		return

	if capture_cooldown > 0.0:
		capture_cooldown -= delta

	if _can_see_player():
		var offset := target_player.global_position - global_position
		last_seen_position = target_player.global_position
		last_seen_direction = offset.normalized()
		state = State.CHASE

	match state:
		State.PATROL:
			_patrol(delta)
		State.SUSPICIOUS:
			_suspicious(delta)
		State.INVESTIGATE:
			_move_toward(investigation_point, patrol_speed + 0.4, delta)
			if global_position.distance_to(investigation_point) < 0.8:
				_begin_search()
		State.CHASE:
			_chase(delta)
		State.SEARCH:
			_search(delta)
		State.GUARD:
			_guard(delta)
		State.RETURN_TO_PATROL:
			_return_to_patrol(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	_animate_uncle(delta)

func _patrol(delta: float) -> void:
	var destination := patrol_points[patrol_index]
	_move_toward(destination, patrol_speed, delta)
	if global_position.distance_to(destination) < 0.8:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		if patrol_index == 0 and not patrol_routes.is_empty():
			_apply_route((route_index + 1) % patrol_routes.size())

func _suspicious(delta: float) -> void:
	_move_toward(investigation_point, patrol_speed * 0.85, delta)
	if global_position.distance_to(investigation_point) < 2.4:
		_begin_search()

func _chase(delta: float) -> void:
	var player_position := target_player.global_position
	_move_toward(player_position, chase_speed, delta)
	if global_position.distance_to(player_position) <= capture_distance and capture_cooldown <= 0.0:
		capture_cooldown = 2.0
		player_captured.emit()
	elif not _can_see_player() and global_position.distance_to(player_position) > vision_distance * 0.9:
		investigation_point = last_seen_position + last_seen_direction * 1.8
		_begin_search()

func _search(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, chase_speed * delta)
	velocity.z = move_toward(velocity.z, 0.0, chase_speed * delta)
	rotate_y(delta * 1.4)
	search_timer -= delta
	if search_timer <= 0.0:
		state = State.RETURN_TO_PATROL

func _guard(delta: float) -> void:
	_move_toward(investigation_point, patrol_speed, delta)
	guard_timer -= delta
	if guard_timer <= 0.0:
		state = State.RETURN_TO_PATROL

func _return_to_patrol(delta: float) -> void:
	var destination := patrol_points[patrol_index]
	_move_toward(destination, patrol_speed, delta)
	if global_position.distance_to(destination) < 0.8:
		state = State.PATROL

func _begin_search() -> void:
	state = State.SEARCH
	var memory_bonus := _suspicion_bonus_for(investigation_point)
	search_timer = search_duration + memory_bonus

func _move_toward(destination: Vector3, speed: float, delta: float) -> void:
	var offset := destination - global_position
	offset.y = 0.0
	if offset.length() < 0.05:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta)
		return

	var direction := offset.normalized()
	velocity.x = move_toward(velocity.x, direction.x * speed, speed * 4.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, speed * 4.0 * delta)
	look_at(global_position + direction, Vector3.UP)

func _can_see_player() -> bool:
	var to_player := target_player.global_position - global_position
	var distance := to_player.length()
	if distance > vision_distance:
		return false

	var forward := -global_transform.basis.z
	var angle := rad_to_deg(forward.angle_to(to_player.normalized()))
	if angle > field_of_view_degrees * 0.5:
		return false

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.25,
		target_player.global_position + Vector3.UP * 0.25
	)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	return result.is_empty() or result.get("collider") == target_player

func _apply_route(index: int) -> void:
	if patrol_routes.is_empty():
		return
	route_index = index
	patrol_points.clear()
	for point in patrol_routes[route_index]:
		if point is Vector3:
			patrol_points.append(point)
	patrol_index = 0

func _remember_suspicion(world_position: Vector3, intensity: float) -> void:
	var bucket := "%d:%d" % [roundi(world_position.x / 6.0), roundi(world_position.z / 6.0)]
	var current := float(suspicion_memory.get(bucket, 0.0))
	suspicion_memory[bucket] = minf(3.0, current + intensity)

func _suspicion_bonus_for(world_position: Vector3) -> float:
	var bucket := "%d:%d" % [roundi(world_position.x / 6.0), roundi(world_position.z / 6.0)]
	return float(suspicion_memory.get(bucket, 0.0)) * 0.45

func _build_uncle_model() -> void:
	for node_name in ["Body", "Head", "Nose"]:
		var old_node := get_node_or_null(node_name)
		if old_node:
			old_node.visible = false

	var model := Node3D.new()
	model.name = "StylizedUncleModel"
	add_child(model)

	var coat := _material(Color(0.16, 0.16, 0.23))
	var coat_dark := _material(Color(0.11, 0.11, 0.17))
	var shirt := _material(Color(0.66, 0.24, 0.18))
	var skin := _material(Color(0.83, 0.58, 0.42))
	var skin_highlight := _material(Color(0.90, 0.66, 0.49))
	var hair := _material(Color(0.10, 0.07, 0.05))
	var shoe := _material(Color(0.05, 0.04, 0.035))
	var eye := _material(Color(0.02, 0.018, 0.015))

	_add_box(model, "WideCoat", Vector3(0.95, 1.25, 0.48), Vector3(0, 0.75, 0), coat)
	_add_box(model, "RedVest", Vector3(0.48, 0.86, 0.08), Vector3(0, 0.78, -0.26), shirt)
	_add_sphere(model, "Head", Vector3(0, 1.62, -0.06), Vector3(0.38, 0.42, 0.35), skin)
	_add_sphere(model, "BulbNose", Vector3(0, 1.57, -0.42), Vector3(0.13, 0.10, 0.12), skin_highlight)
	_add_sphere(model, "LeftEye", Vector3(-0.12, 1.70, -0.36), Vector3(0.045, 0.045, 0.035), eye)
	_add_sphere(model, "RightEye", Vector3(0.12, 1.70, -0.36), Vector3(0.045, 0.045, 0.035), eye)
	_add_box(model, "HeavyBrow", Vector3(0.42, 0.08, 0.08), Vector3(0, 1.78, -0.36), hair)
	_add_sphere(model, "MessyHair", Vector3(0, 1.93, -0.02), Vector3(0.42, 0.16, 0.34), hair)

	for x in [-0.62, 0.62]:
		var arm := _add_cylinder(model, "LongArm", 0.09, 1.0, Vector3(x, 0.82, -0.02), coat)
		arm.rotation.z = 0.18 * sign(x)
		arm_nodes.append(arm)
		_add_sphere(model, "Hand", Vector3(x * 1.04, 0.32, -0.02), Vector3(0.13, 0.11, 0.10), skin)

	for x in [-0.25, 0.25]:
		var leg := _add_cylinder(model, "TrouserLeg", 0.11, 0.9, Vector3(x, -0.22, 0.02), coat_dark)
		leg_nodes.append(leg)
		_add_box(model, "Shoe", Vector3(0.28, 0.12, 0.44), Vector3(x, -0.72, -0.10), shoe)

func _animate_uncle(_delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var chase_mult := 1.6 if state == State.CHASE else 1.0
	var time := Time.get_ticks_msec() / 1000.0
	var stride: float = sin(time * 5.5 * chase_mult) * clampf(speed * 0.18, 0.0, 0.65)
	for i in range(leg_nodes.size()):
		leg_nodes[i].rotation.x = stride if i % 2 == 0 else -stride
	for i in range(arm_nodes.size()):
		arm_nodes[i].rotation.x = -stride if i % 2 == 0 else stride

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
	material.roughness = 0.82
	return material
