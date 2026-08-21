extends Node3D

const REMOTE_DOG := preload("res://scenes/player/RemoteDog.tscn")
const HOUSE_BUILDER := preload("res://scripts/art/stylized_house_builder.gd")
const TOWN_BUILDER := preload("res://scripts/art/grumble_town_builder.gd")
const SEND_RATE := 0.05

@onready var local_player: CharacterBody3D = $Player

var remote_players: Dictionary = {}
var send_timer := 0.0

func _ready() -> void:
	_build_arena()
	local_player.global_position = _spawn_position_for_index(0)
	NetworkClient.player_moved.connect(_on_player_moved)
	NetworkClient.room_state_changed.connect(_on_room_state_changed)
	_on_room_state_changed(NetworkClient.state)

func _physics_process(delta: float) -> void:
	send_timer -= delta
	if send_timer <= 0.0 and NetworkClient.is_open():
		send_timer = SEND_RATE
		NetworkClient.send_player_move(local_player.global_position, local_player.rotation.y)

func _build_arena() -> void:
	var town_builder := TOWN_BUILDER.new()
	town_builder.build(self)
	var builder := HOUSE_BUILDER.new()
	builder.build(self)

func _add_box(node_name: String, size: Vector3, position: Vector3, color: Color, collision := true) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	if collision:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)

func _on_room_state_changed(state: Dictionary) -> void:
	for player_data in state.get("players", []):
		var id := String(player_data.get("sessionId", ""))
		if id.is_empty() or id == NetworkClient.session_id:
			continue
		_ensure_remote_player(id, player_data)

	var live_ids := {}
	for player_data in state.get("players", []):
		live_ids[String(player_data.get("sessionId", ""))] = true

	for id in remote_players.keys():
		if not live_ids.has(id):
			remote_players[id].queue_free()
			remote_players.erase(id)

func _on_player_moved(id: String, position: Vector3, yaw: float) -> void:
	if id == NetworkClient.session_id:
		return
	var remote := _ensure_remote_player(id, {})
	remote.global_position = remote.global_position.lerp(position, 0.55)
	remote.rotation.y = yaw

func _ensure_remote_player(id: String, player_data: Dictionary) -> Node3D:
	if remote_players.has(id):
		return remote_players[id]
	var remote := REMOTE_DOG.instantiate() as Node3D
	remote.name = "Remote_%s" % id
	if player_data.has("name"):
		remote.set_player_name(String(player_data.get("name", "Player")))
	remote.global_position = _spawn_position_for_index(remote_players.size() + 1)
	add_child(remote)
	remote_players[id] = remote
	return remote

func _spawn_position_for_index(index: int) -> Vector3:
	return Vector3(-3.6 + float(index % 4) * 2.4, 0.7, 32.0 + float(index / 4) * 1.8)
