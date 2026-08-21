extends Node

signal connected
signal disconnected
signal error_received(code: String)
signal room_state_changed(state: Dictionary)
signal room_joined(room_code: String, session_id: String)
signal match_started
signal player_moved(session_id: String, position: Vector3, yaw: float)

const LOCAL_SERVER_URL := "ws://localhost:2567/ws"
const WEB_SERVER_URL := "wss://tiny-paws.onrender.com/ws"

var socket := WebSocketPeer.new()
var server_url := _default_server_url()
var session_id := ""
var room_code := ""
var state: Dictionary = {}
var _connected := false

func _process(_delta: float) -> void:
	socket.poll()
	var current_state := socket.get_ready_state()

	if current_state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			connected.emit()
		while socket.get_available_packet_count() > 0:
			_handle_packet(socket.get_packet().get_string_from_utf8())
	elif _connected and current_state == WebSocketPeer.STATE_CLOSED:
		_connected = false
		disconnected.emit()

func connect_to_server(url := "") -> void:
	server_url = url if not url.is_empty() else _default_server_url()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		return
	var err := socket.connect_to_url(server_url)
	if err != OK:
		error_received.emit("CONNECTION_FAILED")

func create_room(player_name: String, dog := "Milo") -> void:
	_send({
		"type": "create_room",
		"name": player_name,
		"dog": dog
	})

func join_room(join_code: String, player_name: String, dog := "Milo") -> void:
	_send({
		"type": "join_room",
		"roomCode": join_code,
		"name": player_name,
		"dog": dog
	})

func set_ready(ready: bool) -> void:
	_send({"type": "set_ready", "ready": ready})

func set_difficulty(difficulty: String) -> void:
	_send({"type": "set_difficulty", "difficulty": difficulty})

func set_game_mode(game_mode: String) -> void:
	_send({"type": "set_game_mode", "gameMode": game_mode})

func volunteer_uncle(volunteer: bool) -> void:
	_send({"type": "volunteer_uncle", "volunteer": volunteer})

func start_game() -> void:
	_send({"type": "start_game"})

func send_player_move(position: Vector3, yaw: float) -> void:
	_send({
		"type": "player_move",
		"position": {"x": position.x, "y": position.y, "z": position.z},
		"yaw": yaw
	})

func is_open() -> bool:
	return socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func is_host() -> bool:
	return not state.is_empty() and state.get("hostSessionId", "") == session_id

func players() -> Array:
	return state.get("players", [])

func _default_server_url() -> String:
	return WEB_SERVER_URL if OS.has_feature("web") else LOCAL_SERVER_URL

func _send(message: Dictionary) -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		error_received.emit("NOT_CONNECTED")
		return
	socket.send_text(JSON.stringify(message))

func _handle_packet(raw: String) -> void:
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var message := parsed as Dictionary
	match String(message.get("type", "")):
		"connected":
			session_id = String(message.get("sessionId", ""))
		"room_created", "room_joined":
			room_code = String(message.get("roomCode", ""))
			session_id = String(message.get("sessionId", session_id))
			room_joined.emit(room_code, session_id)
		"state":
			state = message.get("state", {})
			room_state_changed.emit(state)
		"match_started":
			match_started.emit()
		"player_moved":
			var pos: Variant = message.get("position", {})
			if typeof(pos) == TYPE_DICTIONARY:
				player_moved.emit(
					String(message.get("sessionId", "")),
					Vector3(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)), float(pos.get("z", 0.0))),
					float(message.get("yaw", 0.0))
				)
		"host_disconnected":
			error_received.emit("HOST_DISCONNECTED")
		"error":
			error_received.emit(String(message.get("code", "UNKNOWN_ERROR")))
