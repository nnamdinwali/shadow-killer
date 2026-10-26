@tool
extends Node3D
## Procedural city for the Shadow killer level.
## Everything here is built from native Godot meshes, materials and shader code;
## no imported art is used.
##
## Layout (z axis): the rooftop route runs along +x at z -6..6, a park and the
## far skyline sit behind a river, and the city rolls past the camera in
## parallax layers so the background never runs out.

const LAND_X_MIN := -400.0
const LAND_X_MAX := 9000.0
const HAZE_COLOR := Color(0.78, 0.90, 1.0)

## Parallax skyline layers. "scroll" is the share of the camera speed the layer
## appears to move on screen (1.0 = same as the route, 0.0 = painted on the sky).
## "period" is the repeat distance in meters; layers are built three times side
## by side and wrapped, so the city is endless.
const SKY_LAYERS := [
	{"name": "FarSkyline", "z": -145.0, "scroll": 0.06, "period": 300.0, "count": 18,
		"w_min": 8.0, "w_max": 15.0, "h_min": 22.0, "h_max": 46.0, "depth": 7.0, "haze": 0.38},
	{"name": "MidSkyline", "z": -112.0, "scroll": 0.16, "period": 220.0, "count": 14,
		"w_min": 8.0, "w_max": 14.0, "h_min": 15.0, "h_max": 30.0, "depth": 7.0, "haze": 0.23},
	{"name": "NearSkyline", "z": -78.0, "scroll": 0.30, "period": 150.0, "count": 10,
		"w_min": 7.0, "w_max": 12.0, "h_min": 9.0, "h_max": 19.0, "depth": 6.0, "haze": 0.12},
]

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
var water_material := ShaderMaterial.new()
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

	var water_shader := Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode cull_back;

uniform vec4 shallow_color : source_color = vec4(0.25, 0.88, 0.95, 1.0);
uniform vec4 deep_color : source_color = vec4(0.04, 0.52, 0.88, 1.0);

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float a = sin(wp.x * 0.35 + TIME * 0.9) * 0.5 + 0.5;
	float b = sin(wp.z * 0.9 - TIME * 0.6 + wp.x * 0.1) * 0.5 + 0.5;
	float glint = smoothstep(0.80, 1.0, a * b);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, 0.35 + 0.5 * a * b);
	ALBEDO = col + vec3(glint) * 0.35;
	ROUGHNESS = 0.18;
	SPECULAR = 0.7;
}
"""
	water_material.shader = water_shader

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
	var length := LAND_X_MAX - LAND_X_MIN
	var center_x := (LAND_X_MAX + LAND_X_MIN) * 0.5
	# Depth order from the camera: playable rooftop (z=0), broad water (z=-18),
	# near skyline (-78), mid skyline (-112), then hazy distant skyline (-145).
	# Keep the land strip behind the skyline so it cannot mask the roof supports.
	_box("LandBack", Vector3(center_x, -0.5, -166.0), Vector3(length, 1.0, 36.0), land_back)
	_box("QuayBack", Vector3(center_x, -0.15, -18.0), Vector3(length, 0.3, 0.7), quay)
	_box("River", Vector3(center_x, -0.55, -19.0), Vector3(length, 0.35, 34.0), water_material)


func _build_skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7341
	for config in SKY_LAYERS:
		var layer := Node3D.new()
		layer.name = config["name"]
		generated_root.add_child(layer)
		layer.position = Vector3(0.0, 0.0, config["z"])
		parallax_layers.append({"node": layer, "scroll": config["scroll"], "period": config["period"]})

		var period: float = config["period"]
		var count: int = config["count"]
		var slot := period / float(count)
		var haze: float = config["haze"]
		for i in count:
			var width := rng.randf_range(config["w_min"], min(config["w_max"], slot * 0.95))
			var height := rng.randf_range(config["h_min"], config["h_max"])
			var x_local := -period * 0.5 + (float(i) + 0.5) * slot + rng.randf_range(-slot * 0.1, slot * 0.1)
			var z_off := rng.randf_range(-3.0, 3.0)
			var colors: Array = palette[rng.randi() % palette.size()]
			var base_color: Color = colors[0]
			var window_color: Color = colors[1]
			base_color = base_color.lerp(HAZE_COLOR, haze)
			window_color = window_color.lerp(HAZE_COLOR, haze * 0.8)
			var size := Vector3(width, height, config["depth"])
			for copy in [-1, 0, 1]:
				var pos := Vector3(x_local + float(copy) * period, 0.0, z_off)
				var node_name := "%s_%02d_%d" % [config["name"], i, copy + 1]
				var building := _make_building(node_name, pos, size, base_color, window_color)
				building.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				layer.add_child(building)


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
	# 2.5D side-scrolling route in the foreground play lane.
	# Rooftops are intentionally 1000-2500 world units long so running is the
	# default; gaps are reserved for occasional jumps and web-swing sections.
	# Each entry is [center_x, top_y, length_x, depth_z].
	var segments := [
		[1250.0, 4.8, 2500.0, 12.0],
		[4000.0, 4.8, 2500.0, 12.0],
		[5000.0, 4.8, 1000.0, 12.0],
		[7000.0, 4.8, 2500.0, 12.0]
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
	for x in [-20.0, -10.0, 10.0, 20.0]:
		_build_lamp(x, 17.5)


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