extends Node3D

const REMOTE_DOG := preload("res://scenes/player/RemoteDog.tscn")
const SEND_RATE := 0.05

@onready var local_player: CharacterBody3D = $Player

var remote_players: Dictionary = {}
var send_timer := 0.0

func _ready() -> void:
	_build_arena()
	NetworkClient.player_moved.connect(_on_player_moved)
	NetworkClient.room_state_changed.connect(_on_room_state_changed)
	_on_room_state_changed(NetworkClient.state)

func _physics_process(delta: float) -> void:
	send_timer -= delta
	if send_timer <= 0.0 and NetworkClient.is_open():
		send_timer = SEND_RATE
		NetworkClient.send_player_move(local_player.global_position, local_player.rotation.y)

func _build_arena() -> void:
	_add_box("Floor", Vector3(18, 0.25, 14), Vector3(0, -0.12, 0), Color(0.19, 0.16, 0.14))
	_add_box("Teal Wall", Vector3(18, 3.0, 0.3), Vector3(0, 1.4, -7), Color(0.1, 0.48, 0.55))
	_add_box("Orange Wall", Vector3(0.3, 3.0, 14), Vector3(-9, 1.4, 0), Color(0.88, 0.42, 0.16))
	_add_box("Green Wall", Vector3(0.3, 3.0, 14), Vector3(9, 1.4, 0), Color(0.42, 0.62, 0.34))
	_add_box("Huge Sofa Tunnel", Vector3(4.2, 0.9, 1.3), Vector3(-3.5, 0.45, 1.8), Color(0.07, 0.34, 0.42))
	_add_box("Kitchen Island", Vector3(3.2, 0.9, 1.2), Vector3(4.0, 0.45, -2.0), Color(0.95, 0.78, 0.46))
	_add_box("Round Rug", Vector3(4.8, 0.04, 3.0), Vector3(0, 0.03, 2.8), Color(0.63, 0.18, 0.31), false)

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
	add_child(remote)
	remote_players[id] = remote
	return remote

