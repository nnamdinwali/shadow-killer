@tool
extends Node3D
## Hand-authored city foundation and traversal layer.
## Uses only native Godot meshes, materials, and shader code; no AI-generated assets.

var asphalt := StandardMaterial3D.new()
var sidewalk := StandardMaterial3D.new()
var curb := StandardMaterial3D.new()
var lane_paint := StandardMaterial3D.new()
var metal := StandardMaterial3D.new()
var lamp_glow := StandardMaterial3D.new()
var rooftop := StandardMaterial3D.new()
var rooftop_edge := StandardMaterial3D.new()
var void_material := StandardMaterial3D.new()
var facade_shader := Shader.new()
var facade_materials: Array[ShaderMaterial] = []
var generated_root: Node3D

func _ready() -> void:
	generated_root = get_node_or_null("CityPolishGenerated")
	if generated_root == null:
		generated_root = Node3D.new()
		generated_root.name = "CityPolishGenerated"
		add_child(generated_root)
		generated_root.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else null
	else:
		for child in generated_root.get_children():
			child.free()
	_setup_materials()
	_apply_facade_textures()
	_build_floor()
	_build_road()
	_build_traversal_route()
	_build_street_furniture()
	_build_fall_zone()

func _setup_materials() -> void:
	asphalt.albedo_color = Color("252a30")
	asphalt.roughness = 0.96

	sidewalk.albedo_color = Color("a7a39a")
	sidewalk.roughness = 0.9

	curb.albedo_color = Color("c8c4b9")
	curb.roughness = 0.78

	lane_paint.albedo_color = Color("f4c44f")
	lane_paint.emission_enabled = true
	lane_paint.emission = Color("8c641b")
	lane_paint.emission_energy_multiplier = 0.28
	lane_paint.roughness = 0.58

	metal.albedo_color = Color("303b43")
	metal.metallic = 0.72
	metal.roughness = 0.34

	lamp_glow.albedo_color = Color("ffcc78")
	lamp_glow.emission_enabled = true
	lamp_glow.emission = Color("ff9d32")
	lamp_glow.emission_energy_multiplier = 2.4

	rooftop.albedo_color = Color("393b3d")
	rooftop.roughness = 0.88
	rooftop_edge.albedo_color = Color("b9a47d")
	rooftop_edge.roughness = 0.72

	void_material.albedo_color = Color("0b1420")
	void_material.roughness = 1.0

	facade_shader.code = """
shader_type spatial;
render_mode diffuse_burley, cull_back;

uniform vec4 base_color : source_color = vec4(0.42, 0.58, 0.68, 1.0);
uniform vec4 window_color : source_color = vec4(0.06, 0.16, 0.23, 1.0);
uniform float detail_scale = 1.0;

float hash12(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

void fragment() {
    vec2 cell = UV * vec2(10.0, 18.0) * detail_scale;
    vec2 local = fract(cell);
    vec2 tile = floor(cell);
    float panel = step(0.045, local.x) * step(local.x, 0.955) * step(0.035, local.y) * step(local.y, 0.965);
    float window_frame = step(0.13, local.x) * step(local.x, 0.87) * step(0.12, local.y) * step(local.y, 0.88);
    float window = step(0.19, local.x) * step(local.x, 0.81) * step(0.18, local.y) * step(local.y, 0.82);
    float warm_variation = step(0.84, hash12(tile + 4.0));
    float panel_variation = (hash12(tile + 18.0) - 0.5) * 0.075;
    float seam = (1.0 - step(0.975, local.x)) * 0.10 + (1.0 - step(0.975, local.y)) * 0.08;
    float grime = hash12(tile * 0.7 + 12.0) * 0.075;
    float vertical_weathering = smoothstep(0.72, 1.0, hash12(vec2(tile.x, 3.0))) * (1.0 - local.y) * 0.07;
    vec3 facade = base_color.rgb * (1.0 - grime - seam - vertical_weathering + panel_variation);
    vec3 glass = window_color.rgb + vec3(0.07, 0.095, 0.10) * warm_variation;
    float glass_mask = window * window_frame * panel;
    ALBEDO = mix(facade, glass, glass_mask * 0.88);
    ROUGHNESS = mix(0.91, 0.30, glass_mask);
    SPECULAR = mix(0.28, 0.62, glass_mask);
    EMISSION = glass * glass_mask * (0.008 + warm_variation * 0.028);
}
"""

func _apply_facade_textures() -> void:
	var palette := [
		[Color("9c7767"), Color("172f3b")],
		[Color("b9ad98"), Color("1c3b49")],
		[Color("819792"), Color("20343e")],
		[Color("a88b70"), Color("1b303d")],
		[Color("c0bbb0"), Color("293e48")]
	]
	var index := 0
	for node in get_tree().get_nodes_in_group("facade_buildings"):
		var material := ShaderMaterial.new()
		material.shader = facade_shader
		var colors = palette[index % palette.size()]
		material.set_shader_parameter("base_color", colors[0])
		material.set_shader_parameter("window_color", colors[1])
		material.set_shader_parameter("detail_scale", 0.9 + float(index % 3) * 0.12)
		node.material_override = material
		facade_materials.append(material)
		index += 1

	# The existing scene predates groups, so also catch its named skyline meshes.
	for node in _all_scene_meshes():
		if not _is_facade_name(node.name):
			continue
		var material := ShaderMaterial.new()
		material.shader = facade_shader
		var colors = palette[index % palette.size()]
		material.set_shader_parameter("base_color", colors[0])
		material.set_shader_parameter("window_color", colors[1])
		material.set_shader_parameter("detail_scale", 0.9 + float(index % 3) * 0.12)
		node.material_override = material
		facade_materials.append(material)
		index += 1

func _all_scene_meshes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node in get_tree().get_nodes_in_group("facade_buildings"):
		if node is MeshInstance3D:
			result.append(node)
	for node in find_children("*", "MeshInstance3D", true, false):
		if node is MeshInstance3D and not result.has(node):
			result.append(node)
	return result

func _is_facade_name(node_name: String) -> bool:
	return node_name.contains("Tower") or node_name.contains("Block") or node_name.contains("Building")

func _build_floor() -> void:
	_box("CityFoundation", Vector3(0.0, -0.25, -8.0), Vector3(56.0, 0.45, 34.0), asphalt)
	_box("RearPlaza", Vector3(0.0, 0.02, -10.0), Vector3(50.0, 0.12, 8.0), sidewalk)
	_box("FrontWalk", Vector3(0.0, 0.02, 7.0), Vector3(50.0, 0.12, 6.0), sidewalk)
	# A dark lower void makes the gaps read as dangerous space rather than a
	# second flat floor. It is intentionally below the playable route.
	_box("DeepCityVoid", Vector3(0.0, -8.0, -2.0), Vector3(62.0, 0.30, 24.0), void_material)

func _build_road() -> void:
	_box("Boulevard", Vector3(0.0, 0.12, 1.8), Vector3(48.0, 0.18, 8.6), asphalt)
	_box("BoulevardCurbBack", Vector3(0.0, 0.29, -2.55), Vector3(48.0, 0.20, 0.34), curb)
	_box("BoulevardCurbFront", Vector3(0.0, 0.29, 6.15), Vector3(48.0, 0.20, 0.34), curb)
	for x in range(-21, 22, 6):
		_box("LaneDash_%s" % x, Vector3(x, 0.235, 1.8), Vector3(3.0, 0.035, 0.16), lane_paint)
	_box("EdgeLineBack", Vector3(0.0, 0.235, -1.95), Vector3(47.0, 0.035, 0.12), lane_paint)
	_box("EdgeLineFront", Vector3(0.0, 0.235, 5.55), Vector3(47.0, 0.035, 0.12), lane_paint)
	for x in [-11.0, 11.0]:
		for z in [-0.8, 0.1, 1.0, 1.9, 2.8, 3.7, 4.6]:
			_box("Crosswalk_%s_%s" % [x, z], Vector3(x, 0.245, z), Vector3(0.55, 0.035, 0.52), curb)

func _build_traversal_route() -> void:
	# 2.5D side-scrolling route: matching rooftop platforms with real open gaps.
	# The wide middle gap is reserved for a future long web-swing section.
	var segments := [
		[-19.0, 4.8, 10.0, 4.0],
		[-4.0, 4.8, 10.0, 4.0],
		[14.0, 4.8, 11.0, 4.0],
		[27.0, 4.8, 10.0, 4.0]
	]
	for i in segments.size():
		var item = segments[i]
		_build_rooftop_segment(i, Vector3(item[0], item[1], -6.0), Vector3(item[2], 0.65, item[3]))
		_build_swing_anchor(i, Vector3(item[0] + item[2] * 0.38, item[1] + 8.0, -5.0))


func _build_rooftop_segment(index: int, center: Vector3, size: Vector3) -> void:
	# Give every floating route piece a believable building mass underneath it.
	# The rooftop remains a traversal surface; these blocks are the structure
	# that makes it read as a city rather than an unsupported platform.
	var building_height := center.y - 0.28
	var building_size := Vector3(size.x * 0.88, max(building_height, 1.4), size.z * 0.82)
	var building_center := Vector3(center.x, building_height * 0.5 - 0.2, center.z)
	var building_material := _facade_material(index)
	_box_with_material("RooftopBuilding_%02d" % index, building_center, building_size, building_material)
	_box_with_material("RooftopBuildingCap_%02d" % index, Vector3(center.x, center.y - 0.40, center.z), Vector3(size.x * 0.96, 0.16, size.z * 0.92), rooftop_edge)
	_box("TraversalRoof_%02d" % index, center, size, rooftop)
	_box("TraversalRoofEdge_%02d" % index, center + Vector3(0.0, size.y * 0.52, size.z * 0.48), Vector3(size.x, 0.12, 0.14), rooftop_edge)
	_box("TraversalRoofTrim_%02d" % index, center + Vector3(-size.x * 0.48, size.y * 0.52, 0.0), Vector3(0.14, 0.12, size.z), rooftop_edge)
	# Small rooftop service blocks make the platforms feel occupied and give
	# the player readable cover/obstacles.
	_box("RooftopUnit_%02d" % index, center + Vector3(size.x * 0.18, size.y * 0.85, -0.25), Vector3(1.0, 0.55, 0.8), metal)

func _facade_material(index: int) -> ShaderMaterial:
	var colors: Array = [
		[Color("9c7767"), Color("172f3b")],
		[Color("b9ad98"), Color("1c3b49")],
		[Color("819792"), Color("20343e")],
		[Color("a88b70"), Color("1b303d")],
		[Color("c0bbb0"), Color("293e48")]
	][index % 5]
	var material := ShaderMaterial.new()
	material.shader = facade_shader
	material.set_shader_parameter("base_color", colors[0])
	material.set_shader_parameter("window_color", colors[1])
	material.set_shader_parameter("detail_scale", 0.95 + float(index % 3) * 0.15)
	return material

func _build_swing_anchor(index: int, position: Vector3) -> void:
	var anchor := Marker3D.new()
	anchor.name = "SwingAnchor_%02d" % index
	anchor.position = position
	anchor.add_to_group("swing_anchors")
	generated_root.add_child(anchor)
	# Visible only as a small emissive locator during level design; hide before
	# shipping if the player should not see the traversal markers.
	var beacon := _mesh_box("SwingBeacon", Vector3.ZERO, Vector3(0.22, 0.22, 0.22), lamp_glow)
	beacon.name = "SwingBeacon_%02d" % index
	anchor.add_child(beacon)

func _build_street_furniture() -> void:
	for x in [-20.0, -10.0, 10.0, 20.0]:
		_build_lamp(x, -3.25)
		_build_lamp(x, 6.85, true)
	for x in [-17.0, -5.0, 7.0, 19.0]:
		_build_barrier(x, -2.88)

func _build_lamp(x: float, z: float, reversed_arm: bool = false) -> void:
	var root := Node3D.new()
	root.name = "StreetLamp_%s_%s" % [x, z]
	generated_root.add_child(root)
	root.position = Vector3(x, 0.0, z)
	root.add_child(_mesh_box("Pole", Vector3(0.0, 2.1, 0.0), Vector3(0.14, 4.2, 0.14), metal))
	var arm_x := -0.58 if reversed_arm else 0.58
	root.add_child(_mesh_box("Arm", Vector3(arm_x, 4.05, 0.0), Vector3(1.25, 0.12, 0.12), metal))
	root.add_child(_mesh_box("Lamp", Vector3(arm_x * 2.0, 3.88, 0.0), Vector3(0.34, 0.12, 0.30), lamp_glow))

func _build_barrier(x: float, z: float) -> void:
	var root := Node3D.new()
	root.name = "RoadBarrier_%s" % x
	generated_root.add_child(root)
	root.position = Vector3(x, 0.0, z)
	root.add_child(_mesh_box("PostA", Vector3(-1.0, 0.55, 0.0), Vector3(0.12, 1.1, 0.12), metal))
	root.add_child(_mesh_box("PostB", Vector3(1.0, 0.55, 0.0), Vector3(0.12, 1.1, 0.12), metal))
	root.add_child(_mesh_box("Rail", Vector3(0.0, 0.62, 0.0), Vector3(2.2, 0.16, 0.16), curb))

func _build_fall_zone() -> void:
	var fall_zone := Area3D.new()
	fall_zone.name = "FallZone"
	fall_zone.collision_layer = 0
	fall_zone.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(62.0, 1.0, 24.0)
	shape.shape = box
	shape.position = Vector3(0.0, -8.0, -2.0)
	fall_zone.add_child(shape)
	fall_zone.body_entered.connect(_on_fall_zone_body_entered)
	generated_root.add_child(fall_zone)

func _on_fall_zone_body_entered(body: Node3D) -> void:
	# The player controller can later connect to this signal to trigger a fall
	# animation/restart. Keeping it here makes the level's failure space explicit.
	if body.is_in_group("player"):
		body.set_meta("fell_from_city", true)

func _box(node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := _mesh_box(node_name, position, size, material)
	generated_root.add_child(mesh_instance)
	return mesh_instance

func _box_with_material(node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := _mesh_box(node_name, position, size, material)
	generated_root.add_child(mesh_instance)
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
