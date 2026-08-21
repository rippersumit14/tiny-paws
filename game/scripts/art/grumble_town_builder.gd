extends RefCounted
class_name GrumbleTownBuilder

var root: Node3D

func build(target: Node3D) -> Node3D:
	root = Node3D.new()
	root.name = "GrumbleTownNightExterior"
	target.add_child(root)
	_add_night_environment()
	_add_terrain()
	_add_main_street()
	_add_garden_and_manor_front()
	_add_neighbors()
	_add_park_and_shed()
	_add_lighting()
	return root

func _add_night_environment() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "TownWorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.055, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.27, 0.40)
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.28
	environment.environment = env
	root.add_child(environment)

	var moon := DirectionalLight3D.new()
	moon.name = "LargeCoolMoon"
	moon.rotation_degrees = Vector3(-48, -22, 0)
	moon.light_color = Color(0.60, 0.74, 1.0)
	moon.light_energy = 1.25
	moon.shadow_enabled = true
	root.add_child(moon)

	_sphere("VisibleMoon", 2.8, Vector3(30, 35, -42), Color(1.0, 0.94, 0.70), false)
	for i in range(26):
		_sphere("Star_%02d" % i, 0.06 + (i % 3) * 0.03, Vector3(-45 + (i * 7) % 90, 24 + (i % 5) * 2.5, -52 + (i * 11) % 32), Color(0.85, 0.92, 1.0), false)

func _add_terrain() -> void:
	_box("ReadableGreenGrass", Vector3(120, 0.18, 120), Vector3(0, -0.22, 0), Color(0.08, 0.34, 0.16))
	for i in range(42):
		var x := -52.0 + float((i * 13) % 104)
		var z := -44.0 + float((i * 19) % 88)
		_grass_patch("GrassPatch_%02d" % i, Vector3(x, 0.02, z), Color(0.14, 0.48, 0.18))
	for i in range(18):
		_bush("Bush_%02d" % i, Vector3(-40 + (i * 9) % 80, 0.25, -36 + (i * 17) % 72))
	for i in range(14):
		_tree("Tree_%02d" % i, Vector3(-48 + (i * 15) % 96, 0, -42 + (i * 23) % 84), 0.85 + (i % 4) * 0.14)

func _add_main_street() -> void:
	_box("MainStreet", Vector3(100, 0.08, 8), Vector3(0, -0.08, 41), Color(0.08, 0.10, 0.12))
	_box("StreetCenterStripe", Vector3(90, 0.04, 0.16), Vector3(0, 0.01, 41), Color(0.90, 0.78, 0.34), false)
	_box("FrontWalkway", Vector3(4.0, 0.08, 42), Vector3(0, 0.0, 18), Color(0.20, 0.22, 0.24))
	for x in [-34, -20, 20, 34]:
		_street_lamp("StreetLamp_%s" % x, Vector3(x, 0, 36))

func _add_garden_and_manor_front() -> void:
	_box("FrontGardenPath", Vector3(7.0, 0.07, 18), Vector3(0, 0.02, 22), Color(0.28, 0.24, 0.20))
	_box("LeftHedge", Vector3(18, 1.05, 1.0), Vector3(-11, 0.52, 21), Color(0.07, 0.30, 0.15))
	_box("RightHedge", Vector3(18, 1.05, 1.0), Vector3(11, 0.52, 21), Color(0.07, 0.30, 0.15))
	for x in [-10, -6, 6, 10]:
		_flower_bed("FlowerBed_%s" % x, Vector3(x, 0.06, 27))

	# Exterior silhouette in front of the playable interior volume.
	_box("ManorPorch", Vector3(12, 0.45, 4), Vector3(0, 0.18, 12.8), Color(0.28, 0.16, 0.10))
	_box("ManorPorchRoof", Vector3(13, 0.35, 4.6), Vector3(0, 3.2, 12.8), Color(0.30, 0.07, 0.10), false)
	for x in [-4.8, -1.6, 1.6, 4.8]:
		_cylinder("PorchColumn_%s" % x, 0.17, 3.2, Vector3(x, 1.55, 14.4), Color(0.90, 0.64, 0.36))
		_window("WarmFrontWindow_%s" % x, Vector3(x, 2.0, 11.76))

	_box("AsymLeftTower", Vector3(4.5, 11, 4), Vector3(-13.2, 5.35, 6), Color(0.10, 0.25, 0.38), false)
	_box("AsymRightWing", Vector3(8, 7, 3), Vector3(13.8, 3.4, 4), Color(0.12, 0.30, 0.42), false)
	_roof("LeftTowerRoof", Vector3(-13.2, 11.2, 6), 5.3, Color(0.35, 0.06, 0.12))
	_roof("RightWingRoof", Vector3(13.8, 7.2, 4), 7.6, Color(0.35, 0.06, 0.12))
	_cylinder("CrookedChimneyA", 0.28, 3.2, Vector3(-5.6, 12.8, -2.5), Color(0.18, 0.10, 0.08), Vector3(0.12, 0, 0), false)
	_cylinder("CrookedChimneyB", 0.22, 2.6, Vector3(9.8, 9.2, -1.4), Color(0.18, 0.10, 0.08), Vector3(-0.08, 0, 0), false)

func _add_neighbors() -> void:
	for i in range(4):
		var x := -42.0 + i * 28.0
		_neighbor_home("NeighborHome_%d" % i, Vector3(x, 0, 48 + (i % 2) * 7), Color(0.16 + i * 0.035, 0.24, 0.31 + i * 0.025))
	for x in [-28, 28]:
		_box("SideFence_%s" % x, Vector3(1.0, 1.4, 36), Vector3(x, 0.7, 15), Color(0.34, 0.20, 0.10), false)
	for i in range(10):
		_cylinder("FencePost_%02d" % i, 0.10, 1.5, Vector3(-28 + i * 6.2, 0.75, 33), Color(0.38, 0.22, 0.10), Vector3.ZERO, false)
	_box("FrontFenceRailA", Vector3(58, 0.15, 0.16), Vector3(0, 1.1, 33), Color(0.38, 0.22, 0.10), false)
	_box("FrontFenceRailB", Vector3(58, 0.15, 0.16), Vector3(0, 0.55, 33), Color(0.38, 0.22, 0.10), false)

func _add_park_and_shed() -> void:
	_box("SmallParkGrass", Vector3(22, 0.06, 18), Vector3(-37, 0.03, 16), Color(0.10, 0.38, 0.16))
	_box("ParkBench", Vector3(3.2, 0.35, 0.75), Vector3(-39, 0.55, 18), Color(0.45, 0.25, 0.10))
	_box("ParkBenchBack", Vector3(3.2, 0.8, 0.18), Vector3(-39, 0.95, 18.42), Color(0.34, 0.18, 0.08), false)
	_neighbor_home("AbandonedShed", Vector3(39, 0, 18), Color(0.19, 0.22, 0.18), Vector3(6.0, 3.3, 5.0))
	_box("DrainEntrance", Vector3(3.8, 1.1, 0.45), Vector3(31, 0.55, 30), Color(0.05, 0.06, 0.07))
	for x in [-1.2, -0.4, 0.4, 1.2]:
		_box("DrainBars_%s" % x, Vector3(0.12, 1.1, 0.12), Vector3(31 + x, 0.55, 30.28), Color(0.18, 0.21, 0.24), false)

func _add_lighting() -> void:
	for pos in [Vector3(-8, 3.2, 12), Vector3(8, 3.2, 12), Vector3(0, 2.4, 16), Vector3(-13, 6.8, 6), Vector3(14, 4.8, 4)]:
		var light := OmniLight3D.new()
		light.name = "WarmManorWindowLight"
		light.position = pos
		light.light_color = Color(1.0, 0.62, 0.24)
		light.light_energy = 1.35
		light.omni_range = 7.0
		root.add_child(light)

func _neighbor_home(node_name: String, origin: Vector3, color: Color, size := Vector3(8, 4.2, 6)) -> void:
	_box("%s_Body" % node_name, size, origin + Vector3(0, size.y * 0.5, 0), color, false)
	_roof("%s_Roof" % node_name, origin + Vector3(0, size.y + 0.75, 0), size.x + 1.4, Color(0.28, 0.08, 0.12))
	for x in [-2.2, 2.2]:
		_window("%s_Window_%s" % [node_name, x], origin + Vector3(x, 2.4, -size.z * 0.52))

func _street_lamp(node_name: String, origin: Vector3) -> void:
	_cylinder("%s_Pole" % node_name, 0.10, 4.6, origin + Vector3(0, 2.3, 0), Color(0.08, 0.10, 0.12), Vector3.ZERO, false)
	_sphere("%s_Bulb" % node_name, 0.38, origin + Vector3(0, 4.8, 0), Color(1.0, 0.74, 0.32), false)
	var light := OmniLight3D.new()
	light.name = "%s_Light" % node_name
	light.position = origin + Vector3(0, 4.5, 0)
	light.light_color = Color(1.0, 0.70, 0.32)
	light.light_energy = 1.3
	light.omni_range = 9.0
	root.add_child(light)

func _tree(node_name: String, origin: Vector3, scale_factor: float) -> void:
	_cylinder("%s_Trunk" % node_name, 0.28 * scale_factor, 3.4 * scale_factor, origin + Vector3(0, 1.7 * scale_factor, 0), Color(0.23, 0.12, 0.06), Vector3.ZERO, false)
	_sphere("%s_CrownA" % node_name, 1.6 * scale_factor, origin + Vector3(0, 3.8 * scale_factor, 0), Color(0.08, 0.28, 0.15), false)
	_sphere("%s_CrownB" % node_name, 1.1 * scale_factor, origin + Vector3(0.8 * scale_factor, 4.4 * scale_factor, 0.2), Color(0.10, 0.36, 0.18), false)

func _bush(node_name: String, origin: Vector3) -> void:
	_sphere("%s_A" % node_name, 0.8, origin, Color(0.07, 0.30, 0.15), false)
	_sphere("%s_B" % node_name, 0.55, origin + Vector3(0.6, 0.12, 0.1), Color(0.10, 0.40, 0.18), false)

func _flower_bed(node_name: String, origin: Vector3) -> void:
	_box("%s_Soil" % node_name, Vector3(2.2, 0.08, 1.1), origin, Color(0.18, 0.09, 0.04), false)
	for i in range(5):
		_sphere("%s_Flower_%d" % [node_name, i], 0.12, origin + Vector3(-0.8 + i * 0.4, 0.17, 0.1 * (i % 2)), Color(0.95, 0.32 + 0.08 * i, 0.42), false)

func _grass_patch(node_name: String, origin: Vector3, color: Color) -> void:
	for i in range(5):
		_box("%s_Blade_%d" % [node_name, i], Vector3(0.06, 0.35 + i * 0.04, 0.04), origin + Vector3(-0.25 + i * 0.12, 0.16, 0.03 * i), color, false)

func _window(node_name: String, position: Vector3) -> void:
	_box(node_name, Vector3(1.2, 1.0, 0.08), position, Color(1.0, 0.67, 0.24), false)

func _roof(node_name: String, position: Vector3, width: float, color: Color) -> void:
	_box(node_name, Vector3(width, 0.7, width * 0.55), position, color, false)

func _box(node_name: String, size: Vector3, position: Vector3, color: Color, collision := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	root.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)

	if collision:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
	return body

func _sphere(node_name: String, radius: float, position: Vector3, color: Color, collision := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	root.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)

	if collision:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		shape.shape = sphere
		body.add_child(shape)
	return body

func _cylinder(node_name: String, radius: float, height: float, position: Vector3, color: Color, rotation := Vector3.ZERO, collision := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation = rotation
	root.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)

	if collision:
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = height
		shape.shape = cylinder
		body.add_child(shape)
	return body

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
