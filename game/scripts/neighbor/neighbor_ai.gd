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
@export var debug_ai := false

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
var astar := AStar3D.new()
var nav_waypoints: Array[Vector3] = []
var current_path: Array[Vector3] = []
var path_index := 0
var active_destination := Vector3.ZERO
var has_active_destination := false
var repath_timer := 0.0
var stuck_probe_timer := 0.0
var stuck_timer := 0.0
var stuck_probe_position := Vector3.ZERO
var last_good_position := Vector3.ZERO
var movement_expected := false
var chase_lost_timer := 0.0
var committed_target_time := 0.0
var ai_debug_label: Label3D

const PATH_RECALC_SECONDS := 0.38
const CHASE_RECALC_SECONDS := 0.18
const WAYPOINT_REACHED_DISTANCE := 0.7
const STUCK_SAMPLE_SECONDS := 0.55
const STUCK_DISTANCE_THRESHOLD := 0.09
const STUCK_RECOVERY_SECONDS := 1.35
const CHASE_COMMIT_SECONDS := 2.0

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
	stuck_probe_position = global_position
	last_good_position = global_position
	_build_debug_label()

func configure_routes(routes: Array) -> void:
	patrol_routes.clear()
	for route in routes:
		if route is Array and not route.is_empty():
			patrol_routes.append(route)
	if not patrol_routes.is_empty():
		_apply_route(0)
	_build_navigation_graph()

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
	_clear_navigation_path()

func guard_at(world_position: Vector3, duration: float) -> void:
	investigation_point = world_position
	guard_timer = maxf(duration, 0.5)
	state = State.GUARD
	capture_cooldown = maxf(capture_cooldown, 2.0)
	_set_navigation_destination(investigation_point, true)

func hear_noise(world_position: Vector3, intensity: float) -> void:
	if state == State.CHASE:
		return
	var radius: float = 10.0 * maxf(intensity, 0.2) * hearing_sensitivity
	if global_position.distance_to(world_position) <= radius:
		_remember_suspicion(world_position, intensity)
		investigation_point = world_position
		state = State.SUSPICIOUS
		_set_navigation_destination(investigation_point, true)

func _physics_process(delta: float) -> void:
	if not target_player:
		return

	repath_timer = maxf(0.0, repath_timer - delta)
	committed_target_time = maxf(0.0, committed_target_time - delta)
	if capture_cooldown > 0.0:
		capture_cooldown -= delta

	if _can_see_player():
		var offset := target_player.global_position - global_position
		last_seen_position = target_player.global_position
		last_seen_direction = offset.normalized()
		chase_lost_timer = 0.0
		committed_target_time = CHASE_COMMIT_SECONDS
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

	_update_stuck_watchdog(delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	_animate_uncle(delta)
	_update_debug_label()

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
	_move_toward(player_position, chase_speed, delta, true)
	if global_position.distance_to(player_position) <= capture_distance and capture_cooldown <= 0.0 and _has_clear_grab():
		capture_cooldown = 2.0
		player_captured.emit()
	elif not _can_see_player():
		chase_lost_timer += delta
		investigation_point = last_seen_position + last_seen_direction * 1.8
		_move_toward(investigation_point, chase_speed * 0.92, delta, true)
		if chase_lost_timer > 0.8 and global_position.distance_to(investigation_point) < 1.2:
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
	_clear_navigation_path()
	var memory_bonus := _suspicion_bonus_for(investigation_point)
	search_timer = search_duration + memory_bonus

func _move_toward(destination: Vector3, speed: float, delta: float, chase_repath := false) -> void:
	_set_navigation_destination(destination, false, CHASE_RECALC_SECONDS if chase_repath else PATH_RECALC_SECONDS)
	var steering_target := _next_path_position()
	var offset := steering_target - global_position
	offset.y = 0.0
	if offset.length() < 0.05:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta)
		movement_expected = false
		return

	var direction := offset.normalized()
	velocity.x = move_toward(velocity.x, direction.x * speed, speed * 4.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, speed * 4.0 * delta)
	look_at(global_position + direction, Vector3.UP)
	movement_expected = true

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

func _has_clear_grab() -> bool:
	if not target_player:
		return false
	return _segment_clear(global_position, target_player.global_position, true)

func _apply_route(index: int) -> void:
	if patrol_routes.is_empty():
		return
	route_index = index
	patrol_points.clear()
	for point in patrol_routes[route_index]:
		if point is Vector3:
			patrol_points.append(point)
	patrol_index = 0
	_clear_navigation_path()

func _build_navigation_graph() -> void:
	astar.clear()
	nav_waypoints.clear()

	var authored_points := [
		Vector3(0, 0.9, 32), Vector3(0, 0.9, 24), Vector3(0, 0.9, 16), Vector3(0, 0.9, 8),
		Vector3(0, 0.9, -5.8), Vector3(-12, 0.9, -6.5), Vector3(11, 0.9, -5.6),
		Vector3(-8.5, 0.9, 4.2), Vector3(-1.8, 0.9, 7.4), Vector3(7, 0.9, 5.8),
		Vector3(11.6, 0.9, 0.8), Vector3(12.4, 0.9, 6.7), Vector3(12.4, 2.2, 2.5),
		Vector3(12.4, 4.9, -3.1), Vector3(-10, 4.9, -7.4), Vector3(0, 4.9, -2.0),
		Vector3(8.5, 4.9, -7.0), Vector3(9.2, 4.9, 7.0), Vector3(-9.5, 4.9, 7.0),
		Vector3(12.4, 4.9, -6.3), Vector3(12.4, 6.4, -10.2), Vector3(12.4, 8.9, -14.4),
		Vector3(-10.0, 8.9, -7.4), Vector3(0, 8.9, 0.0), Vector3(10.0, 8.9, -7.4),
		Vector3(9.8, 8.9, 7.0), Vector3(-9.4, 8.9, 7.4), Vector3(-37, 0.9, 16),
		Vector3(31, 0.9, 30), Vector3(39, 0.9, 18)
	]
	for route in patrol_routes:
		for point in route:
			if point is Vector3:
				authored_points.append(point)
	for point in authored_points:
		_add_nav_waypoint(point)

	for i in range(nav_waypoints.size()):
		astar.add_point(i, nav_waypoints[i])

	for i in range(nav_waypoints.size()):
		for j in range(i + 1, nav_waypoints.size()):
			var a := nav_waypoints[i]
			var b := nav_waypoints[j]
			var same_floor := absf(a.y - b.y) < 0.35
			var stair_link := absf(a.x - b.x) < 0.35 and absf(a.z - b.z) < 5.0 and absf(a.y - b.y) <= 2.9
			if (same_floor and a.distance_to(b) <= 10.5 and _segment_clear(a, b)) or stair_link:
				astar.connect_points(i, j)

func _add_nav_waypoint(point: Vector3) -> void:
	for existing in nav_waypoints:
		if existing.distance_to(point) < 0.2:
			return
	nav_waypoints.append(point)

func _set_navigation_destination(destination: Vector3, force := false, interval := PATH_RECALC_SECONDS) -> void:
	if not force and has_active_destination and active_destination.distance_to(destination) < 0.45 and not current_path.is_empty():
		return
	if not force and repath_timer > 0.0:
		return

	active_destination = destination
	has_active_destination = true
	repath_timer = interval
	current_path = _make_path_to(destination)
	path_index = 0

func _make_path_to(destination: Vector3) -> Array[Vector3]:
	if _segment_clear(global_position, destination):
		return [destination]
	if astar.get_point_count() == 0:
		return [_jitter_destination(destination)]

	var start_id := _nearest_reachable_waypoint(global_position)
	var end_id := _nearest_reachable_waypoint(destination)
	if start_id == -1 or end_id == -1:
		return [_jitter_destination(destination)]

	var packed_path := astar.get_point_path(start_id, end_id)
	var result: Array[Vector3] = []
	for point in packed_path:
		result.append(point)
	if result.is_empty():
		result.append(nav_waypoints[start_id])
	if _segment_clear(result[result.size() - 1], destination):
		result.append(destination)
	return result

func _nearest_reachable_waypoint(from_position: Vector3) -> int:
	var best_id := -1
	var best_score := INF
	for i in range(nav_waypoints.size()):
		var point := nav_waypoints[i]
		var distance := from_position.distance_to(point)
		var visible_penalty := 0.0 if _segment_clear(from_position, point) else 18.0
		var score := distance + visible_penalty + absf(from_position.y - point.y) * 4.0
		if score < best_score:
			best_score = score
			best_id = i
	return best_id

func _next_path_position() -> Vector3:
	if current_path.is_empty():
		return active_destination if has_active_destination else global_position
	while path_index < current_path.size() - 1 and global_position.distance_to(current_path[path_index]) < WAYPOINT_REACHED_DISTANCE:
		path_index += 1
	return current_path[path_index]

func _clear_navigation_path() -> void:
	current_path.clear()
	path_index = 0
	has_active_destination = false
	movement_expected = false

func _segment_clear(from_position: Vector3, to_position: Vector3, allow_player_hit := false) -> bool:
	var from := from_position + Vector3.UP * 0.85
	var to := to_position + Vector3.UP * 0.85
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider = result.get("collider")
	return allow_player_hit and collider == target_player

func _update_stuck_watchdog(delta: float) -> void:
	stuck_probe_timer += delta
	if stuck_probe_timer < STUCK_SAMPLE_SECONDS:
		return

	var moved := global_position.distance_to(stuck_probe_position)
	if movement_expected and moved < STUCK_DISTANCE_THRESHOLD:
		stuck_timer += stuck_probe_timer
	else:
		stuck_timer = 0.0
		if moved >= STUCK_DISTANCE_THRESHOLD:
			last_good_position = global_position

	stuck_probe_position = global_position
	stuck_probe_timer = 0.0

	if stuck_timer >= STUCK_RECOVERY_SECONDS:
		_recover_from_stuck()

func _recover_from_stuck() -> void:
	stuck_timer = 0.0
	repath_timer = 0.0
	if has_active_destination:
		_set_navigation_destination(_jitter_destination(active_destination), true)
	if current_path.is_empty():
		var fallback_id := _nearest_reachable_waypoint(last_good_position)
		if fallback_id != -1:
			current_path = [nav_waypoints[fallback_id]]
			path_index = 0

func _jitter_destination(destination: Vector3) -> Vector3:
	var angle := randf() * TAU
	var radius := randf_range(0.65, 1.55)
	return destination + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

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

func _build_debug_label() -> void:
	ai_debug_label = Label3D.new()
	ai_debug_label.name = "UncleAIDebug"
	ai_debug_label.position = Vector3(0, 2.5, 0)
	ai_debug_label.pixel_size = 0.018
	ai_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ai_debug_label.visible = debug_ai and OS.has_feature("editor")
	add_child(ai_debug_label)

func _update_debug_label() -> void:
	if not ai_debug_label:
		return
	ai_debug_label.visible = debug_ai and OS.has_feature("editor")
	if not ai_debug_label.visible:
		return
	ai_debug_label.text = "%s\npath %d/%d\nstuck %.1f" % [
		State.keys()[state],
		path_index + 1,
		current_path.size(),
		stuck_timer
	]

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
