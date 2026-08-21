extends CharacterBody3D

signal player_captured

enum State {
	PATROL,
	INVESTIGATE,
	CHASE,
	SEARCH,
	RETURN_TO_PATROL
}

@export var patrol_speed := 2.0
@export var chase_speed := 3.4
@export var vision_distance := 7.5
@export var field_of_view_degrees := 95.0
@export var capture_distance := 0.85
@export var search_duration := 2.2

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target_player: CharacterBody3D
var patrol_points: Array[Vector3] = []
var patrol_index := 0
var state := State.PATROL
var investigation_point := Vector3.ZERO
var search_timer := 0.0
var capture_cooldown := 0.0

func configure(player: CharacterBody3D, points: Array) -> void:
	target_player = player
	patrol_points.clear()
	for point in points:
		if point is Vector3:
			patrol_points.append(point)
	if patrol_points.is_empty():
		patrol_points.append(global_position)

func reset_patrol() -> void:
	state = State.RETURN_TO_PATROL
	capture_cooldown = 1.5

func hear_noise(world_position: Vector3, intensity: float) -> void:
	if state == State.CHASE:
		return
	if global_position.distance_to(world_position) <= 10.0 * max(intensity, 0.2):
		investigation_point = world_position
		state = State.INVESTIGATE

func _physics_process(delta: float) -> void:
	if not target_player:
		return

	if capture_cooldown > 0.0:
		capture_cooldown -= delta

	if _can_see_player():
		state = State.CHASE

	match state:
		State.PATROL:
			_patrol(delta)
		State.INVESTIGATE:
			_move_toward(investigation_point, patrol_speed + 0.4, delta)
			if global_position.distance_to(investigation_point) < 0.8:
				_begin_search()
		State.CHASE:
			_chase(delta)
		State.SEARCH:
			_search(delta)
		State.RETURN_TO_PATROL:
			_return_to_patrol(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()

func _patrol(delta: float) -> void:
	var destination := patrol_points[patrol_index]
	_move_toward(destination, patrol_speed, delta)
	if global_position.distance_to(destination) < 0.8:
		patrol_index = (patrol_index + 1) % patrol_points.size()

func _chase(delta: float) -> void:
	var player_position := target_player.global_position
	_move_toward(player_position, chase_speed, delta)
	if global_position.distance_to(player_position) <= capture_distance and capture_cooldown <= 0.0:
		capture_cooldown = 2.0
		player_captured.emit()
	elif not _can_see_player() and global_position.distance_to(player_position) > vision_distance * 0.9:
		investigation_point = player_position
		_begin_search()

func _search(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, chase_speed * delta)
	velocity.z = move_toward(velocity.z, 0.0, chase_speed * delta)
	rotate_y(delta * 1.4)
	search_timer -= delta
	if search_timer <= 0.0:
		state = State.RETURN_TO_PATROL

func _return_to_patrol(delta: float) -> void:
	var destination := patrol_points[patrol_index]
	_move_toward(destination, patrol_speed, delta)
	if global_position.distance_to(destination) < 0.8:
		state = State.PATROL

func _begin_search() -> void:
	state = State.SEARCH
	search_timer = search_duration

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
