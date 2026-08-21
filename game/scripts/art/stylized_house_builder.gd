extends RefCounted
class_name TinyPawsHouseBuilder

const FLOOR_HEIGHT := 4.0
const WALL_HEIGHT := 3.45

var root: Node3D

func build(target: Node3D) -> Node3D:
	root = Node3D.new()
	root.name = "StylizedThreeFloorHouse"
	target.add_child(root)

	_add_world_presentation()
	_add_architecture()
	_add_room_props()
	_add_lighting()
	_add_exterior_yard()
	return root

func _add_world_presentation() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.11, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.29, 0.38)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.18
	environment.environment = env
	root.add_child(environment)

func _add_architecture() -> void:
	for level in range(3):
		var y := level * FLOOR_HEIGHT
		var floor_colors: Array[Color] = [Color(0.42, 0.29, 0.19), Color(0.33, 0.25, 0.35), Color(0.26, 0.31, 0.39)]
		var floor_color: Color = floor_colors[level]
		_box("Floor_%d" % level, Vector3(32, 0.28, 24), Vector3(0, y - 0.14, 0), floor_color)
		_box("Ceiling_%d" % level, Vector3(32, 0.16, 24), Vector3(0, y + WALL_HEIGHT, 0), Color(0.13, 0.16, 0.2), false)

		_wall_x("BackWall_%d" % level, -16, 16, -12, y, Color(0.13, 0.45, 0.52))
		_wall_z("LeftWall_%d" % level, -16, -12, 12, y, Color(0.85, 0.43, 0.18))
		_wall_z("RightWall_%d" % level, 16, -12, 12, y, Color(0.35, 0.58, 0.31))
		_wall_x("FrontWall_Left_%d" % level, -16, -2.0, 12, y, Color(0.20, 0.42, 0.58))
		_wall_x("FrontWall_Right_%d" % level, 2.0, 16, 12, y, Color(0.20, 0.42, 0.58))

		_add_trim_for_level(level, y)

	# Ground floor rooms.
	_wall_z_gap("Kitchen_Dining_Wall", -5.4, -12, 1.8, -2.0, 2.6, 0, Color(0.78, 0.72, 0.52))
	_wall_z_gap("Study_Garage_Wall", 5.4, -12, 1.8, -2.0, 2.4, 0, Color(0.18, 0.25, 0.40))
	_wall_x_gap("Hall_Back_Wall", -16, 16, 1.8, -1.0, 4.6, 0, Color(0.15, 0.50, 0.56))
	_wall_x_gap("Storage_Garage_Wall", -16, 16, 6.2, 8.0, 3.2, 0, Color(0.39, 0.49, 0.33))

	# Second floor rooms.
	_wall_z_gap("Guest_Bath_Wall", -5.0, -12, 12, 0.0, 2.2, 1, Color(0.46, 0.28, 0.55))
	_wall_z_gap("Uncle_Hobby_Wall", 5.0, -12, 12, 0.0, 2.2, 1, Color(0.53, 0.29, 0.23))
	_wall_x_gap("Second_Hall_Back", -16, 16, -2.0, -9.0, 2.3, 1, Color(0.18, 0.38, 0.56))
	_wall_x_gap("Second_Hall_Front", -16, 16, 5.6, 9.2, 2.8, 1, Color(0.20, 0.45, 0.52))

	# Third floor rooms.
	_wall_z_gap("Security_OldBedroom_Wall", -4.0, -12, 12, -4.0, 2.2, 2, Color(0.25, 0.40, 0.52))
	_wall_z_gap("Workshop_Storage_Wall", 4.0, -12, 12, 4.0, 2.2, 2, Color(0.52, 0.36, 0.18))
	_wall_x_gap("Third_Center_Wall", -16, 16, 0.0, 0.0, 4.2, 2, Color(0.28, 0.27, 0.42))

	_add_staircase(0)
	_add_staircase(1)
	_add_windows_and_doors()

func _add_trim_for_level(level: int, y: float) -> void:
	for z in [-11.82, 11.82]:
		_box("Baseboard_X_%d_%s" % [level, z], Vector3(31.4, 0.16, 0.14), Vector3(0, y + 0.24, z), Color(0.98, 0.72, 0.38), false)
		_box("Crown_X_%d_%s" % [level, z], Vector3(31.4, 0.16, 0.14), Vector3(0, y + 3.15, z), Color(0.98, 0.72, 0.38), false)
	for x in [-15.82, 15.82]:
		_box("Baseboard_Z_%d_%s" % [level, x], Vector3(0.14, 0.16, 23.4), Vector3(x, y + 0.24, 0), Color(0.98, 0.72, 0.38), false)
		_box("Crown_Z_%d_%s" % [level, x], Vector3(0.14, 0.16, 23.4), Vector3(x, y + 3.15, 0), Color(0.98, 0.72, 0.38), false)

func _add_staircase(level: int) -> void:
	var base_y := level * FLOOR_HEIGHT
	var base_z := 6.7 - level * 13.0
	var x := 12.4
	var step_count := 18
	var total_run := 8.4
	for i in range(step_count):
		var t := float(i) / float(step_count - 1)
		var step_y := base_y + 0.12 + t * (FLOOR_HEIGHT - 0.34)
		var step_z := base_z - t * total_run
		_box("VisibleStep_%d_%02d" % [level, i], Vector3(3.0, 0.22, 0.52), Vector3(x, step_y, step_z), Color(0.40, 0.25, 0.14), false)
		_box("StepNose_%d_%02d" % [level, i], Vector3(3.12, 0.12, 0.08), Vector3(x, step_y + 0.13, step_z - 0.25), Color(0.94, 0.62, 0.28), false)

	var ramp := StaticBody3D.new()
	ramp.name = "InvisibleStairAssist_%d" % level
	ramp.position = Vector3(x, base_y + 1.95, base_z - total_run * 0.5)
	ramp.rotation.x = -atan(FLOOR_HEIGHT / total_run)
	root.add_child(ramp)
	var ramp_shape := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(3.2, 0.2, total_run + 0.8)
	ramp_shape.shape = ramp_box
	ramp.add_child(ramp_shape)

	_box("StairLanding_%d" % level, Vector3(4.0, 0.24, 3.0), Vector3(x, base_y + FLOOR_HEIGHT - 0.12, base_z - total_run - 1.4), Color(0.38, 0.24, 0.14))
	_box("LeftRail_%d" % level, Vector3(0.16, 1.0, total_run + 1.8), Vector3(x - 1.75, base_y + 2.3, base_z - total_run * 0.5), Color(0.14, 0.10, 0.08), false)
	_box("RightRail_%d" % level, Vector3(0.16, 1.0, total_run + 1.8), Vector3(x + 1.75, base_y + 2.3, base_z - total_run * 0.5), Color(0.14, 0.10, 0.08), false)
	for i in range(6):
		var z := base_z - 0.8 - i * 1.35
		_box("RailPost_%d_%d_L" % [level, i], Vector3(0.22, 1.35, 0.22), Vector3(x - 1.75, base_y + 1.15 + i * 0.18, z), Color(0.12, 0.08, 0.06), false)
		_box("RailPost_%d_%d_R" % [level, i], Vector3(0.22, 1.35, 0.22), Vector3(x + 1.75, base_y + 1.15 + i * 0.18, z), Color(0.12, 0.08, 0.06), false)

func _add_windows_and_doors() -> void:
	for level in range(3):
		var y := level * FLOOR_HEIGHT
		for x in [-11.5, -6.0, 6.0, 11.5]:
			_box("WindowBack_%d_%s" % [level, x], Vector3(1.6, 1.1, 0.08), Vector3(x, y + 1.9, -11.84), Color(0.65, 0.86, 1.0), false)
			_box("WindowFront_%d_%s" % [level, x], Vector3(1.6, 1.1, 0.08), Vector3(x, y + 1.9, 11.84), Color(0.65, 0.86, 1.0), false)
			_box("WindowFrameBack_%d_%s" % [level, x], Vector3(1.9, 1.35, 0.05), Vector3(x, y + 1.9, -11.9), Color(0.98, 0.74, 0.40), false)
	_box("FrontDoor", Vector3(2.8, 3.0, 0.16), Vector3(0, 1.48, 11.9), Color(0.42, 0.16, 0.08), false)
	_box("DoorKnob", Vector3(0.16, 0.16, 0.08), Vector3(0.95, 1.55, 12.02), Color(1.0, 0.76, 0.24), false)

func _add_room_props() -> void:
	_add_living_room()
	_add_kitchen()
	_add_dining_room()
	_add_study()
	_add_garage()
	_add_storage(Vector3(-11, 0, 8), 0)
	_add_bedroom(Vector3(-10, FLOOR_HEIGHT, -7.6), "GuestBedroom", Color(0.50, 0.26, 0.62))
	_add_bathroom(Vector3(-10, FLOOR_HEIGHT, 7.6))
	_add_bedroom(Vector3(9.5, FLOOR_HEIGHT, -7.2), "UnclesBedroom", Color(0.55, 0.20, 0.22))
	_add_hobby_room(Vector3(9.4, FLOOR_HEIGHT, 7.2), 1)
	_add_security_room(Vector3(-10, FLOOR_HEIGHT * 2, -7.5))
	_add_bedroom(Vector3(-9.4, FLOOR_HEIGHT * 2, 7.4), "OldBedroom", Color(0.40, 0.29, 0.52))
	_add_workshop(Vector3(9.4, FLOOR_HEIGHT * 2, -7.6))
	_add_storage(Vector3(9.8, FLOOR_HEIGHT * 2, 7.0), 2)

func _add_living_room() -> void:
	_rug("LivingRug", Vector3(-3.0, 0.03, 4.1), 3.8, 2.4, Color(0.75, 0.18, 0.28))
	_sofa("HugeTealSofa", Vector3(-6.8, 0, 4.0), Color(0.05, 0.42, 0.50))
	_table("CoffeeTable", Vector3(-2.2, 0, 4.2), Color(0.52, 0.30, 0.14))
	_lamp("LivingLamp", Vector3(-10.4, 0, 2.4), Color(1.0, 0.72, 0.32))
	_shelf("MediaShelf", Vector3(1.4, 0, 5.4), Color(0.30, 0.17, 0.10))
	_box("TinyPawsTV", Vector3(2.0, 1.1, 0.16), Vector3(1.4, 1.45, 5.05), Color(0.05, 0.08, 0.12), false)
	for i in range(5):
		_sphere("ScatteredToy_%d" % i, 0.18, Vector3(-1.0 + i * 0.55, 0.2, 7.0 + sin(i) * 0.5), Color(0.95, 0.42, 0.18))

func _add_kitchen() -> void:
	_box("KitchenTile", Vector3(9.6, 0.04, 7.5), Vector3(-10.6, 0.04, -6.4), Color(0.76, 0.88, 0.65), false)
	for i in range(5):
		_box("KitchenCabinet_%d" % i, Vector3(1.5, 1.1, 0.75), Vector3(-14.0 + i * 1.8, 0.55, -10.4), Color(0.95, 0.84, 0.52))
	_box("Fridge", Vector3(1.35, 2.25, 1.0), Vector3(-14.7, 1.1, -7.2), Color(0.84, 0.92, 0.92))
	_box("Stove", Vector3(1.6, 1.0, 1.0), Vector3(-9.8, 0.5, -7.2), Color(0.18, 0.20, 0.22))
	_table("KitchenIsland", Vector3(-11.7, 0, -3.8), Color(0.95, 0.72, 0.30), Vector3(3.3, 0.28, 1.35))
	for i in range(7):
		_sphere("Dish_%d" % i, 0.13, Vector3(-13.8 + i * 0.42, 1.18, -10.0), Color(0.93, 0.95, 0.87))

func _add_dining_room() -> void:
	_rug("DiningRug", Vector3(0.0, 0.03, -5.8), 3.8, 2.8, Color(0.93, 0.64, 0.22))
	_table("GiantDiningTable", Vector3(0, 0, -5.7), Color(0.42, 0.22, 0.10), Vector3(4.6, 0.28, 2.2))
	for x in [-2.9, -1.5, 1.5, 2.9]:
		_chair("DiningChair_%s" % x, Vector3(x, 0, -7.25), Color(0.76, 0.42, 0.21))
		_chair("DiningChair_B_%s" % x, Vector3(x, 0, -4.1), Color(0.76, 0.42, 0.21))

func _add_study() -> void:
	_box("StudyCarpet", Vector3(8.8, 0.04, 7.0), Vector3(10.5, 0.04, -6.6), Color(0.15, 0.23, 0.39), false)
	_shelf("TallBookcaseA", Vector3(14.6, 0, -9.4), Color(0.24, 0.13, 0.08))
	_shelf("TallBookcaseB", Vector3(8.6, 0, -9.4), Color(0.24, 0.13, 0.08))
	_table("StudyDesk", Vector3(11.5, 0, -4.8), Color(0.44, 0.22, 0.10), Vector3(3.4, 0.30, 1.5))
	_lamp("AmberDeskLamp", Vector3(12.5, 0.98, -4.8), Color(1.0, 0.64, 0.25), 1.0)
	_box("SuspiciousPainting", Vector3(2.4, 1.4, 0.10), Vector3(15.82, 1.8, -5.8), Color(0.82, 0.32, 0.20), false)

func _add_garage() -> void:
	_box("GarageFloor", Vector3(9.6, 0.04, 4.6), Vector3(-10.6, 0.04, 4.0), Color(0.27, 0.36, 0.32), false)
	for i in range(6):
		_box("GarageBox_%d" % i, Vector3(1.0 + i % 2 * 0.4, 0.8, 1.0), Vector3(-14.0 + i * 1.2, 0.4, 5.0 + (i % 2) * 1.1), Color(0.56, 0.34, 0.14))
	_box("ToolBench", Vector3(3.2, 1.0, 0.75), Vector3(-9.0, 0.5, 2.4), Color(0.18, 0.36, 0.24))
	for i in range(5):
		_box("HangingTool_%d" % i, Vector3(0.16, 0.8, 0.08), Vector3(-10.2 + i * 0.5, 1.7, 2.0), Color(0.88, 0.70, 0.24), false)

func _add_bedroom(origin: Vector3, prefix: String, fabric: Color) -> void:
	_rug("%s_Rug" % prefix, origin + Vector3(0.6, 0.03, 0.8), 3.0, 2.0, fabric.lightened(0.2))
	_bed("%s_Bed" % prefix, origin + Vector3(-1.8, 0, -0.6), fabric)
	_shelf("%s_Wardrobe" % prefix, origin + Vector3(2.2, 0, -2.4), Color(0.34, 0.18, 0.10))
	_table("%s_Nightstand" % prefix, origin + Vector3(0.9, 0, -1.8), Color(0.42, 0.23, 0.13), Vector3(0.9, 0.28, 0.8))
	_lamp("%s_Lamp" % prefix, origin + Vector3(0.9, 0.65, -1.8), Color(1.0, 0.68, 0.30), 0.8)

func _add_bathroom(origin: Vector3) -> void:
	_box("BathroomTile", Vector3(8.0, 0.04, 6.2), origin + Vector3(0, 0.04, 0), Color(0.60, 0.82, 0.84), false)
	_box("Tub", Vector3(2.6, 0.75, 1.3), origin + Vector3(-2.2, 0.38, -1.9), Color(0.88, 0.94, 0.94))
	_box("Sink", Vector3(1.5, 0.8, 0.8), origin + Vector3(1.9, 0.4, -2.1), Color(0.90, 0.94, 0.90))
	_cylinder("RoundMirror", 0.7, 0.08, origin + Vector3(1.9, 1.65, -2.55), Color(0.55, 0.78, 0.92), Vector3(PI / 2.0, 0, 0), false)

func _add_hobby_room(origin: Vector3, level: int) -> void:
	_table("HobbyTable_%d" % level, origin + Vector3(0, 0, 0), Color(0.48, 0.28, 0.16), Vector3(3.2, 0.28, 1.7))
	for i in range(8):
		_box("ModelPart_%d_%d" % [level, i], Vector3(0.35, 0.2, 0.45), origin + Vector3(-1.3 + i * 0.38, 0.95, sin(i) * 0.55), Color(0.85, 0.50, 0.20), false)
	_shelf("HobbyShelf_%d" % level, origin + Vector3(2.7, 0, -2.2), Color(0.30, 0.20, 0.12))

func _add_security_room(origin: Vector3) -> void:
	_box("SecurityDesk", Vector3(3.4, 1.0, 1.2), origin + Vector3(0, 0.5, -1.5), Color(0.16, 0.20, 0.24))
	for i in range(4):
		_box("SecurityMonitor_%d" % i, Vector3(0.9, 0.55, 0.10), origin + Vector3(-1.35 + i * 0.9, 1.25, -2.1), Color(0.14, 0.78, 0.72), false)
	_cylinder("CableCoil", 0.7, 0.22, origin + Vector3(-2.5, 0.18, 1.5), Color(0.05, 0.06, 0.07))

func _add_workshop(origin: Vector3) -> void:
	_table("WorkshopBench", origin + Vector3(0, 0, -1.2), Color(0.42, 0.27, 0.13), Vector3(4.2, 0.32, 1.2))
	for i in range(7):
		_box("PaintCan_%d" % i, Vector3(0.32, 0.45, 0.32), origin + Vector3(-2.0 + i * 0.55, 0.25, 0.9), Color(0.20 + 0.1 * (i % 3), 0.55, 0.75 - 0.07 * i))
	_lamp("WorkshopLamp", origin + Vector3(1.5, 1.0, -1.2), Color(1.0, 0.86, 0.45), 1.1)

func _add_storage(origin: Vector3, level: int) -> void:
	for i in range(10):
		_box("Storage_%d_Box_%d" % [level, i], Vector3(0.9 + (i % 3) * 0.25, 0.65, 0.9), origin + Vector3((i % 5) * 1.0 - 2.0, 0.32 + int(i / 5) * 0.68, (i % 2) * 1.2 - 0.5), Color(0.48, 0.30, 0.14))
	_shelf("StorageShelf_%d" % level, origin + Vector3(2.8, 0, 0.6), Color(0.22, 0.18, 0.14))

func _add_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "CoolMoonSun"
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_energy = 0.75
	sun.light_color = Color(0.58, 0.72, 1.0)
	sun.shadow_enabled = true
	root.add_child(sun)

	for level in range(3):
		var y := level * FLOOR_HEIGHT
		for pos in [Vector3(-10, y + 2.65, -7), Vector3(0, y + 2.65, 3), Vector3(10, y + 2.65, -6), Vector3(8, y + 2.65, 7)]:
			var light := OmniLight3D.new()
			light.name = "WarmRoomLight"
			light.position = pos
			light.light_energy = 1.2
			light.omni_range = 8.0
			light.light_color = Color(1.0, 0.72, 0.42)
			light.shadow_enabled = false
			root.add_child(light)
			_cylinder("CeilingFixture", 0.35, 0.12, pos + Vector3(0, 0.18, 0), Color(1.0, 0.78, 0.42), Vector3.ZERO, false)

func _add_exterior_yard() -> void:
	_box("ExteriorGrass", Vector3(42, 0.12, 34), Vector3(0, -0.24, 0), Color(0.18, 0.42, 0.22), false)
	for i in range(8):
		var x := -18.0 + i * 5.0
		_cylinder("FencePost_%d" % i, 0.12, 1.2, Vector3(x, 0.45, 15.0), Color(0.40, 0.24, 0.12), Vector3.ZERO, false)
	_box("FenceRailA", Vector3(38, 0.16, 0.16), Vector3(0, 0.8, 15.0), Color(0.40, 0.24, 0.12), false)
	_box("FenceRailB", Vector3(38, 0.16, 0.16), Vector3(0, 0.35, 15.0), Color(0.40, 0.24, 0.12), false)

func _sofa(node_name: String, origin: Vector3, color: Color) -> void:
	_box("%s_Base" % node_name, Vector3(4.2, 0.55, 1.45), origin + Vector3(0, 0.45, 0), color)
	_box("%s_Back" % node_name, Vector3(4.4, 1.25, 0.38), origin + Vector3(0, 0.85, 0.75), color.darkened(0.12))
	_box("%s_LeftArm" % node_name, Vector3(0.42, 0.95, 1.6), origin + Vector3(-2.3, 0.75, 0), color.lightened(0.08))
	_box("%s_RightArm" % node_name, Vector3(0.42, 0.95, 1.6), origin + Vector3(2.3, 0.75, 0), color.lightened(0.08))
	for i in range(3):
		_box("%s_Cushion_%d" % [node_name, i], Vector3(1.15, 0.22, 1.18), origin + Vector3(-1.25 + i * 1.25, 0.85, -0.10), color.lightened(0.18), false)

func _bed(node_name: String, origin: Vector3, fabric: Color) -> void:
	_box("%s_Frame" % node_name, Vector3(3.8, 0.55, 2.7), origin + Vector3(0, 0.42, 0), Color(0.36, 0.18, 0.08))
	_box("%s_Blanket" % node_name, Vector3(3.55, 0.22, 2.3), origin + Vector3(0, 0.84, 0.08), fabric, false)
	_box("%s_PillowA" % node_name, Vector3(1.1, 0.25, 0.65), origin + Vector3(-0.75, 1.05, -0.85), Color(0.94, 0.86, 0.76), false)
	_box("%s_PillowB" % node_name, Vector3(1.1, 0.25, 0.65), origin + Vector3(0.75, 1.05, -0.85), Color(0.94, 0.86, 0.76), false)

func _table(node_name: String, origin: Vector3, color: Color, top_size := Vector3(2.4, 0.24, 1.3)) -> void:
	_box("%s_Top" % node_name, top_size, origin + Vector3(0, 0.82, 0), color)
	for x in [-top_size.x * 0.38, top_size.x * 0.38]:
		for z in [-top_size.z * 0.35, top_size.z * 0.35]:
			_cylinder("%s_Leg" % node_name, 0.09, 0.78, origin + Vector3(x, 0.40, z), color.darkened(0.18))

func _chair(node_name: String, origin: Vector3, color: Color) -> void:
	_box("%s_Seat" % node_name, Vector3(0.78, 0.20, 0.78), origin + Vector3(0, 0.55, 0), color)
	_box("%s_Back" % node_name, Vector3(0.78, 0.86, 0.18), origin + Vector3(0, 0.96, 0.38), color.darkened(0.1))
	for x in [-0.28, 0.28]:
		for z in [-0.28, 0.28]:
			_cylinder("%s_Leg" % node_name, 0.06, 0.55, origin + Vector3(x, 0.28, z), color.darkened(0.2))

func _shelf(node_name: String, origin: Vector3, color: Color) -> void:
	_box("%s_Frame" % node_name, Vector3(2.2, 2.35, 0.55), origin + Vector3(0, 1.15, 0), color)
	for i in range(4):
		_box("%s_Shelf_%d" % [node_name, i], Vector3(2.05, 0.10, 0.62), origin + Vector3(0, 0.35 + i * 0.55, 0), color.lightened(0.12), false)
	for i in range(10):
		_box("%s_Book_%d" % [node_name, i], Vector3(0.14, 0.42, 0.18), origin + Vector3(-0.85 + i * 0.18, 0.62 + (i % 3) * 0.55, -0.34), Color(0.25 + 0.06 * (i % 4), 0.25, 0.70 - 0.04 * i), false)

func _lamp(node_name: String, origin: Vector3, color: Color, energy := 1.3) -> void:
	_cylinder("%s_Pole" % node_name, 0.06, 1.25, origin + Vector3(0, 0.62, 0), Color(0.20, 0.14, 0.08), Vector3.ZERO, false)
	_cylinder("%s_Shade" % node_name, 0.42, 0.42, origin + Vector3(0, 1.25, 0), color, Vector3.ZERO, false)
	var light := OmniLight3D.new()
	light.name = "%s_Light" % node_name
	light.position = origin + Vector3(0, 1.22, 0)
	light.light_energy = energy
	light.omni_range = 4.5
	light.light_color = color
	root.add_child(light)

func _rug(node_name: String, position: Vector3, radius_x: float, radius_z: float, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.position = position
	mesh.scale = Vector3(radius_x, 1.0, radius_z)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 0.03
	cylinder.radial_segments = 48
	mesh.mesh = cylinder
	mesh.material_override = _material(color)
	root.add_child(mesh)

func _wall_x(name: String, x1: float, x2: float, z: float, y: float, color: Color) -> void:
	_box(name, Vector3(abs(x2 - x1), WALL_HEIGHT, 0.24), Vector3((x1 + x2) * 0.5, y + WALL_HEIGHT * 0.5, z), color)

func _wall_z(name: String, x: float, z1: float, z2: float, y: float, color: Color) -> void:
	_box(name, Vector3(0.24, WALL_HEIGHT, abs(z2 - z1)), Vector3(x, y + WALL_HEIGHT * 0.5, (z1 + z2) * 0.5), color)

func _wall_x_gap(name: String, x1: float, x2: float, z: float, gap_center: float, gap_width: float, level: int, color: Color) -> void:
	var y := level * FLOOR_HEIGHT
	_wall_x("%s_A" % name, x1, gap_center - gap_width * 0.5, z, y, color)
	_wall_x("%s_B" % name, gap_center + gap_width * 0.5, x2, z, y, color)
	_box("%s_DoorFrameTop" % name, Vector3(gap_width + 0.45, 0.24, 0.36), Vector3(gap_center, y + 2.8, z), Color(0.96, 0.68, 0.36), false)

func _wall_z_gap(name: String, x: float, z1: float, z2: float, gap_center: float, gap_width: float, level: int, color: Color) -> void:
	var y := level * FLOOR_HEIGHT
	_wall_z("%s_A" % name, x, z1, gap_center - gap_width * 0.5, y, color)
	_wall_z("%s_B" % name, x, gap_center + gap_width * 0.5, z2, y, color)
	_box("%s_DoorFrameTop" % name, Vector3(0.36, 0.24, gap_width + 0.45), Vector3(x, y + 2.8, gap_center), Color(0.96, 0.68, 0.36), false)

func _box(node_name: String, size: Vector3, position: Vector3, color: Color, collision := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	root.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)

	if collision:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)

	return body

func _sphere(node_name: String, radius: float, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_instance.mesh = sphere
	mesh_instance.material_override = _material(color)
	root.add_child(mesh_instance)
	return mesh_instance

func _cylinder(node_name: String, radius: float, height: float, position: Vector3, color: Color, rotation := Vector3.ZERO, collision := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation = rotation
	root.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 24
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)

	if collision:
		var shape := CollisionShape3D.new()
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = radius
		cylinder_shape.height = height
		shape.shape = cylinder_shape
		body.add_child(shape)

	return body

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	material.metallic = 0.0
	return material
