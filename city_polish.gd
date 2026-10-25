extends Node3D
## Hand-authored city foundation for the Shadow Killer showcase scene.
## Uses only native Godot meshes/materials; no downloaded or AI-generated assets.

var asphalt := StandardMaterial3D.new()
var sidewalk := StandardMaterial3D.new()
var curb := StandardMaterial3D.new()
var lane_paint := StandardMaterial3D.new()
var metal := StandardMaterial3D.new()
var lamp_glow := StandardMaterial3D.new()

func _ready() -> void:
	_setup_materials()
	_build_floor()
	_build_road()
	_build_street_furniture()

func _setup_materials() -> void:
	asphalt.albedo_color = Color("202832")
	asphalt.roughness = 0.96

	sidewalk.albedo_color = Color("7f8994")
	sidewalk.roughness = 0.9

	curb.albedo_color = Color("d2d8dc")
	curb.roughness = 0.78

	lane_paint.albedo_color = Color("f4c44f")
	lane_paint.emission_enabled = true
	lane_paint.emission = Color("8c641b")
	lane_paint.emission_energy_multiplier = 0.28
	lane_paint.roughness = 0.58

	metal.albedo_color = Color("293640")
	metal.metallic = 0.72
	metal.roughness = 0.34

	lamp_glow.albedo_color = Color("ffcc78")
	lamp_glow.emission_enabled = true
	lamp_glow.emission = Color("ff9d32")
	lamp_glow.emission_energy_multiplier = 2.4

func _build_floor() -> void:
	# A broad, dark foundation removes the editor-grid feeling and gives every
	# building a believable base plane.
	_box("CityFoundation", Vector3(0.0, -0.25, -8.0), Vector3(56.0, 0.45, 34.0), asphalt)
	_box("RearPlaza", Vector3(0.0, 0.02, -10.0), Vector3(50.0, 0.12, 8.0), sidewalk)
	_box("FrontWalk", Vector3(0.0, 0.02, 7.0), Vector3(50.0, 0.12, 6.0), sidewalk)

func _build_road() -> void:
	# Main horizontal boulevard in the camera's foreground.
	_box("Boulevard", Vector3(0.0, 0.12, 1.8), Vector3(48.0, 0.18, 8.6), asphalt)
	_box("BoulevardCurbBack", Vector3(0.0, 0.29, -2.55), Vector3(48.0, 0.20, 0.34), curb)
	_box("BoulevardCurbFront", Vector3(0.0, 0.29, 6.15), Vector3(48.0, 0.20, 0.34), curb)

	# Broken center markings and solid edge lines are deliberately simple,
	# readable, and light enough for mobile rendering.
	for x in range(-21, 22, 6):
		_box("LaneDash_%s" % x, Vector3(x, 0.235, 1.8), Vector3(3.0, 0.035, 0.16), lane_paint)
	_box("EdgeLineBack", Vector3(0.0, 0.235, -1.95), Vector3(47.0, 0.035, 0.12), lane_paint)
	_box("EdgeLineFront", Vector3(0.0, 0.235, 5.55), Vector3(47.0, 0.035, 0.12), lane_paint)

	# Two raised pedestrian crossings give the road a designed destination.
	for x in [-11.0, 11.0]:
		for z in [-0.8, 0.1, 1.0, 1.9, 2.8, 3.7, 4.6]:
			_box("Crosswalk_%s_%s" % [x, z], Vector3(x, 0.245, z), Vector3(0.55, 0.035, 0.52), curb)

func _build_street_furniture() -> void:
	for x in [-20.0, -10.0, 10.0, 20.0]:
		_build_lamp(x, -3.25)
		_build_lamp(x, 6.85, true)

	for x in [-17.0, -5.0, 7.0, 19.0]:
		_build_barrier(x, -2.88)

func _build_lamp(x: float, z: float, reversed_arm: bool = false) -> void:
	var root := Node3D.new()
	root.name = "StreetLamp_%s_%s" % [x, z]
	add_child(root)

	var pole := _mesh_box("Pole", Vector3(0.0, 2.1, 0.0), Vector3(0.14, 4.2, 0.14), metal)
	root.add_child(pole)
	var arm_x := -0.58 if reversed_arm else 0.58
	var arm := _mesh_box("Arm", Vector3(arm_x, 4.05, 0.0), Vector3(1.25, 0.12, 0.12), metal)
	root.add_child(arm)
	var lamp := _mesh_box("Lamp", Vector3(arm_x * 2.0, 3.88, 0.0), Vector3(0.34, 0.12, 0.30), lamp_glow)
	root.add_child(lamp)
	root.position = Vector3(x, 0.0, z)

func _build_barrier(x: float, z: float) -> void:
	var root := Node3D.new()
	root.name = "RoadBarrier_%s" % x
	add_child(root)
	root.position = Vector3(x, 0.0, z)
	root.add_child(_mesh_box("PostA", Vector3(-1.0, 0.55, 0.0), Vector3(0.12, 1.1, 0.12), metal))
	root.add_child(_mesh_box("PostB", Vector3(1.0, 0.55, 0.0), Vector3(0.12, 1.1, 0.12), metal))
	root.add_child(_mesh_box("Rail", Vector3(0.0, 0.62, 0.0), Vector3(2.2, 0.16, 0.16), curb))

func _box(node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := _mesh_box(node_name, position, size, material)
	add_child(mesh_instance)
	return mesh_instance

func _mesh_box(node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = position
	return mesh_instance
