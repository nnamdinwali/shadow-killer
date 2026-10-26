@tool
extends Node3D
## Procedural city for the Shadow killer level.
## Everything here is built from native Godot meshes, materials and shader code;
## no imported art is used.
##
## Layout: close foreground rooftop route, a simple street/terrain band, and
## sparse low-rise neighborhood buildings far behind it. No water or tower wall.

const LAND_X_MIN := -400.0
const LAND_X_MAX := 9000.0
const HAZE_COLOR := Color(0.78, 0.90, 1.0)

## The distant neighborhood moves slowly for subtle depth.
const CLOUD_NODES := ["CloudLayerFar", "CloudLayerMid", "CloudLayerHigh"]

var asphalt := StandardMaterial3D.new()
var land_front := StandardMaterial3D.new()
var land_back := StandardMaterial3D.new()
var quay := StandardMaterial3D.new()
var curb := StandardMaterial3D.new()
var metal := StandardMaterial3D.new()
var pole := StandardMaterial3D.new()
var lamp_glow := StandardMaterial3D.new()
var rooftop := StandardMaterial3D.new()
var rooftop_edge := StandardMaterial3D.new()
var building_shader := Shader.new()
var building_material := ShaderMaterial.new()
var palette: Array = []
var generated_root: Node3D
var parallax_layers: Array = []
var cloud_nodes: Array = []


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
	parallax_layers.clear()
	cloud_nodes.clear()
	_setup_materials()
	_build_ground()
	_build_skyline()
	_build_traversal_route()
	_build_street_furniture()
	_build_fall_zone()
	for cloud_name in CLOUD_NODES:
		var cloud := get_node_or_null(cloud_name) as Node3D
		if cloud != null:
			cloud_nodes.append({"node": cloud, "offset": cloud.position.x})


func _process(_delta: float) -> void:
	# Parallax only runs in the game, so the editor view stays put.
	if Engine.is_editor_hint():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cx := cam.global_position.x
	for layer in parallax_layers:
		var node: Node3D = layer["node"]
		var period: float = layer["period"]
		var offset := -cx * float(layer["scroll"])
		offset = fposmod(offset + period * 0.5, period) - period * 0.5
		node.position.x = cx + offset
	for cloud in cloud_nodes:
		var cloud_node: Node3D = cloud["node"]
		cloud_node.position.x = cx + float(cloud["offset"])


func _setup_materials() -> void:
	asphalt.albedo_color = Color("3b4252")
	asphalt.roughness = 0.95

	land_front.albedo_color = Color("d9b97a")
	land_front.roughness = 0.92

	land_back.albedo_color = Color("5fbf45")
	land_back.roughness = 0.95

	quay.albedo_color = Color("c9a063")
	quay.roughness = 0.85

	curb.albedo_color = Color("fff3d6")
	curb.roughness = 0.78

	metal.albedo_color = Color("2fa3b5")
	metal.metallic = 0.15
	metal.roughness = 0.5

	pole.albedo_color = Color("4d6a85")
	pole.metallic = 0.5
	pole.roughness = 0.4

	lamp_glow.albedo_color = Color("ffe08a")
	lamp_glow.emission_enabled = true
	lamp_glow.emission = Color("ffc34d")
	lamp_glow.emission_energy_multiplier = 1.6

	rooftop.albedo_color = Color("d8c29a")
	rooftop.roughness = 0.9
	rooftop_edge.albedo_color = Color("ff6b57")
	rooftop_edge.roughness = 0.7


	# One shader draws every building. Colors and size come per building
	# through instance uniforms, and windows are laid out in meters so a
	# small tower and a long rooftop building both get properly sized windows.
	building_shader.code = """
shader_type spatial;
render_mode diffuse_burley, cull_back;

instance uniform vec4 base_color : source_color = vec4(0.97, 0.62, 0.52, 1.0);
instance uniform vec4 window_color : source_color = vec4(0.30, 0.56, 0.80, 1.0);
instance uniform vec3 box_size = vec3(10.0, 20.0, 6.0);
uniform vec2 cell_size = vec2(2.4, 2.2);

varying vec3 v_pos;
varying vec3 v_nrm;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
}

void fragment() {
	vec3 n = abs(v_nrm);
	bool along_x = n.x > n.z;
	float width = along_x ? box_size.z : box_size.x;
	float u = along_x ? v_pos.z : v_pos.x;
	float v = v_pos.y + box_size.y * 0.5;
	float is_wall = step(n.y, 0.5);

	float cols = max(1.0, floor(width / cell_size.x));
	float rows = max(1.0, floor(box_size.y / cell_size.y));
	vec2 g = vec2((u + width * 0.5) / width * cols, v / box_size.y * rows);
	vec2 cell = floor(g);
	vec2 f = fract(g);

	float pane = step(0.16, f.x) * step(f.x, 0.84) * step(0.18, f.y) * step(f.y, 0.82);
	// Tall buildings keep a plain ground-floor band.
	float skip_row = rows >= 4.0 ? 1.0 - step(1.0, cell.y) : 0.0;
	float glass = pane * is_wall * (1.0 - skip_row);
	float shade = 0.82 + 0.3 * hash12(cell + floor(box_size.xy));
	float ledge = step(f.y, 0.07) * is_wall;

	vec3 wall = base_color.rgb * (1.0 - 0.10 * ledge);
	vec3 pane_col = window_color.rgb * shade;
	ALBEDO = mix(wall, pane_col, glass * 0.92);
	ROUGHNESS = mix(0.85, 0.22, glass);
	SPECULAR = mix(0.3, 0.7, glass);
}
"""
	building_material.shader = building_shader

	palette = [
		[Color("ff6f59"), Color("2f6fb8")],  # coral red
		[Color("ffc93c"), Color("2f6fb8")],  # sunshine yellow
		[Color("2fd08a"), Color("2a63ad")],  # green
		[Color("3d8bff"), Color("1f4f9e")],  # royal blue
		[Color("a66bff"), Color("2f63b5")],  # purple
		[Color("ff9a3c"), Color("2f6fb8")],  # orange
		[Color("19c3cf"), Color("2a5fa8")],  # teal
		[Color("ffe9a8"), Color("3a78c4")],  # cream
		[Color("ff5f9e"), Color("2f6fb8")],  # pink
	]


func _build_ground() -> void:
	# Distant land and a quiet street sit behind the playable rooftop.
	var length := LAND_X_MAX - LAND_X_MIN
	var center_x := (LAND_X_MAX + LAND_X_MIN) * 0.5
	_box("DistantTerrain", Vector3(center_x, -1.7, -105.0), Vector3(length, 2.0, 70.0), land_back)
	_box("BackStreet", Vector3(center_x, -0.55, -49.0), Vector3(length, 0.25, 24.0), asphalt)
	_box("StreetSidewalk", Vector3(center_x, -0.35, -35.5), Vector3(length, 0.3, 3.0), land_front)
	_box("StreetCurb", Vector3(center_x, -0.18, -37.0), Vector3(length, 0.18, 0.25), curb)
	# Sparse lane markings give the background a recognizable street scale.
	for x in range(int(LAND_X_MIN), int(LAND_X_MAX), 34):
		_box("LaneMark_%d" % x, Vector3(float(x), -0.405, -49.0), Vector3(12.0, 0.025, 0.18), curb)


func _build_skyline() -> void:
	# Low, scattered neighborhood buildings: one calm background band, not stacked towers.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7341
	var layer := Node3D.new()
	layer.name = "DistantNeighborhood"
	generated_root.add_child(layer)
	layer.position = Vector3.ZERO
	parallax_layers.append({"node": layer, "scroll": 0.06, "period": 320.0})
	var x := -150.0
	var index := 0
	while x < 170.0:
		var width := rng.randf_range(5.0, 11.0)
		var height := rng.randf_range(4.0, 11.0)
		var depth := rng.randf_range(4.0, 7.0)
		var colors: Array = palette[rng.randi() % palette.size()]
		var haze_color := Color(0.73, 0.82, 0.84)
		var base_color: Color = colors[0].lerp(haze_color, 0.42)
		var window_color: Color = colors[1].lerp(Color(0.62, 0.73, 0.78), 0.35)
		var z := rng.randf_range(-83.0, -67.0)
		var building := _make_building("NeighborhoodBuilding_%02d" % index, Vector3(x, -0.6, z), Vector3(width, height, depth), base_color, window_color)
		building.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.add_child(building)
		# Occasional trees and small roadside blocks break up the skyline silhouette.
		if index % 3 == 0:
			var trunk := _mesh_box("TreeTrunk_%02d" % index, Vector3(x + width * 0.65, 1.0, -42.0), Vector3(0.35, 2.0, 0.35), pole)
			generated_root.add_child(trunk)
			var foliage := _mesh_box("TreeCanopy_%02d" % index, Vector3(x + width * 0.65, 2.5, -42.0), Vector3(2.2, 2.2, 2.0), land_back)
			generated_root.add_child(foliage)
		x += width + rng.randf_range(3.0, 8.0)
		index += 1


func _make_building(node_name: String, base_pos: Vector3, size: Vector3, base_color: Color, window_color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = building_material
	mesh_instance.position = Vector3(base_pos.x, base_pos.y + size.y * 0.5, base_pos.z)
	mesh_instance.set_instance_shader_parameter("base_color", base_color)
	mesh_instance.set_instance_shader_parameter("window_color", window_color)
	mesh_instance.set_instance_shader_parameter("box_size", size)
	return mesh_instance


func _build_traversal_route() -> void:
	# Foreground gameplay rooftops stay close to the camera; gaps are swing sections.
	var segments := [
		[22.0, 4.8, 44.0, 12.0],
		[83.0, 4.8, 42.0, 12.0],
		[145.0, 4.8, 44.0, 12.0],
		[208.0, 4.8, 46.0, 12.0]
	]
	for i in segments.size():
		var item = segments[i]
		_build_rooftop_segment(i, Vector3(item[0], item[1], 0.0), Vector3(item[2], 0.65, item[3]))
		_build_swing_anchor(i, Vector3(item[0] + item[2] * 0.38, item[1] + 8.0, 1.0))


func _build_rooftop_segment(index: int, center: Vector3, size: Vector3) -> void:
	var colors: Array = palette[index % palette.size()]
	# Extend the colored building mass from ground level to the roof underside.
	var ground_y := 0.0
	var roof_bottom_y := center.y - size.y * 0.5
	var building_height: float = maxf(roof_bottom_y - ground_y, 1.0)
	var building_size := Vector3(size.x * 0.88, building_height, size.z * 0.82)
	var building := _make_building("RooftopBuilding_%02d" % index, Vector3(center.x, ground_y, center.z), building_size, colors[0], colors[1])
	generated_root.add_child(building)
	_box("RooftopBuildingCap_%02d" % index, Vector3(center.x, roof_bottom_y - 0.08, center.z), Vector3(size.x * 0.96, 0.16, size.z * 0.92), rooftop_edge)
	_solid_box("TraversalRoof_%02d" % index, center, size, rooftop)
	_box("TraversalRoofEdge_%02d" % index, center + Vector3(0.0, size.y * 0.52, size.z * 0.48), Vector3(size.x, 0.12, 0.14), rooftop_edge)
	_box("TraversalRoofTrim_%02d" % index, center + Vector3(-size.x * 0.48, size.y * 0.52, 0.0), Vector3(0.14, 0.12, size.z), rooftop_edge)
	_box("RooftopUnit_%02d" % index, center + Vector3(size.x * 0.18, size.y * 0.85, -0.25), Vector3(1.0, 0.55, 0.8), metal)


func _build_swing_anchor(index: int, position: Vector3) -> void:
	var anchor := Marker3D.new()
	anchor.name = "SwingAnchor_%02d" % index
	anchor.position = position
	anchor.add_to_group("swing_anchors")
	generated_root.add_child(anchor)
	# Small glowing locator for level design; hide before shipping if the
	# player should not see the traversal markers.
	var beacon := _mesh_box("SwingBeacon", Vector3.ZERO, Vector3(0.22, 0.22, 0.22), lamp_glow)
	beacon.name = "SwingBeacon_%02d" % index
	anchor.add_child(beacon)


func _build_street_furniture() -> void:
	for x in [-30.0, 0.0, 30.0, 60.0, 90.0, 120.0]:
		_build_lamp(x, -38.0)


func _build_lamp(x: float, z: float) -> void:
	var root := Node3D.new()
	root.name = "StreetLamp_%s_%s" % [x, z]
	generated_root.add_child(root)
	root.position = Vector3(x, 0.0, z)
	root.add_child(_mesh_box("Pole", Vector3(0.0, 2.1, 0.0), Vector3(0.14, 4.2, 0.14), pole))
	root.add_child(_mesh_box("Arm", Vector3(-0.58, 4.05, 0.0), Vector3(1.25, 0.12, 0.12), pole))
	root.add_child(_mesh_box("Lamp", Vector3(-1.16, 3.88, 0.0), Vector3(0.34, 0.12, 0.30), lamp_glow))


func _build_fall_zone() -> void:
	var fall_zone := Area3D.new()
	fall_zone.name = "FallZone"
	fall_zone.collision_layer = 0
	fall_zone.collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LAND_X_MAX - LAND_X_MIN, 1.0, 24.0)
	shape.shape = box
	shape.position = Vector3((LAND_X_MAX + LAND_X_MIN) * 0.5, -8.0, -2.0)
	fall_zone.add_child(shape)
	fall_zone.body_entered.connect(_on_fall_zone_body_entered)
	generated_root.add_child(fall_zone)


func _on_fall_zone_body_entered(body: Node3D) -> void:
	# The player controller can later connect to this signal to trigger a fall
	# animation/restart.
	if body.is_in_group("player"):
		body.set_meta("fell_from_city", true)


func _solid_box(node_name: String, position: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var mesh_instance := _mesh_box("Mesh", Vector3.ZERO, size, material)
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	generated_root.add_child(body)
	return body


func _box(node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
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