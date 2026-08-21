extends Node3D

@onready var name_label: Label3D = $NameLabel

var previous_position := Vector3.ZERO
var leg_nodes: Array[Node3D] = []
var tail_node: Node3D

func _ready() -> void:
	previous_position = global_position
	_build_stylized_dog()

func _process(_delta: float) -> void:
	var speed := global_position.distance_to(previous_position) * 18.0
	previous_position = global_position
	var time := Time.get_ticks_msec() / 1000.0
	var stride: float = sin(time * 7.5) * clampf(speed, 0.0, 0.55)
	for i in range(leg_nodes.size()):
		leg_nodes[i].rotation.x = stride if i % 2 == 0 else -stride
	if tail_node:
		tail_node.rotation.z = 0.8 + sin(time * 7.0) * 0.22

func set_player_name(player_name: String) -> void:
	if name_label:
		name_label.text = player_name

func _build_stylized_dog() -> void:
	for node_name in ["Body", "Head"]:
		var old_node := get_node_or_null(node_name)
		if old_node:
			old_node.visible = false

	var model := Node3D.new()
	model.name = "RemoteBeanModel"
	add_child(model)

	var fur := _material(Color(0.82, 0.46, 0.22))
	var dark_fur := _material(Color(0.22, 0.12, 0.08))
	var nose := _material(Color(0.04, 0.035, 0.03))
	var eye := _material(Color(0.02, 0.018, 0.015))

	_add_sphere(model, "LongDachshundTorso", Vector3(0, 0.18, 0.08), Vector3(0.34, 0.25, 0.78), fur)
	_add_sphere(model, "BeanHead", Vector3(0, 0.46, -0.52), Vector3(0.34, 0.25, 0.32), fur)
	_add_sphere(model, "LongMuzzle", Vector3(0, 0.42, -0.82), Vector3(0.20, 0.12, 0.26), dark_fur)
	_add_sphere(model, "Nose", Vector3(0, 0.43, -1.03), Vector3(0.08, 0.055, 0.05), nose)
	_add_sphere(model, "LeftEye", Vector3(-0.12, 0.54, -0.76), Vector3(0.045, 0.045, 0.035), eye)
	_add_sphere(model, "RightEye", Vector3(0.12, 0.54, -0.76), Vector3(0.045, 0.045, 0.035), eye)
	_add_box(model, "LeftLongEar", Vector3(0.11, 0.34, 0.08), Vector3(-0.28, 0.38, -0.54), dark_fur)
	_add_box(model, "RightLongEar", Vector3(0.11, 0.34, 0.08), Vector3(0.28, 0.38, -0.54), dark_fur)

	for x in [-0.21, 0.21]:
		for z in [-0.42, 0.46]:
			var leg := _add_cylinder(model, "ShortLeg", 0.055, 0.28, Vector3(x, -0.02, z), fur)
			leg_nodes.append(leg)
			_add_sphere(model, "TinyPaw", Vector3(x, -0.17, z - 0.02), Vector3(0.10, 0.045, 0.13), dark_fur)

	tail_node = _add_cylinder(model, "HappyTail", 0.045, 0.55, Vector3(0, 0.28, 0.84), fur)
	tail_node.rotation.x = PI / 2.0
	tail_node.rotation.z = 0.8

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
