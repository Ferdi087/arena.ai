extends RefCounted
class_name VehicleBuilder
## Prozeduraler Truck-Aufbau: Kabine, Pritsche, Lichter, Paint-Material.
## Ersetzbar 1:1 durch data.mesh_scene sobald Assets da sind (#123).

static func build(body: RigidBody3D, data: VehicleData) -> Node3D:
	var root := Node3D.new()
	root.name = "BodyVisual"
	body.add_child(root)
	var style := _style()
	var primary := data.primary_color
	var secondary := data.secondary_color
	var mat_main: StandardMaterial3D = style.get_flat_material(StringName("veh_%s" % data.id), primary, 0.45) if style != null else _fallback(primary)
	var mat_dark: StandardMaterial3D = style.get_flat_material(StringName("vehd_%s" % data.id), secondary, 0.6) if style != null else _fallback(secondary)
	var he := data.body_half_extents
	# Kabine (vorne = -Z)
	var cabin := _box(root, Vector3(he.x * 1.96, he.y * 1.15, he.z * 0.62), Vector3(0, he.y * 0.45, -he.z * 0.66), mat_main)
	cabin.name = "Cabin"
	# Windschutz + Fenster
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.35, 0.5, 0.62, 0.55)
	glass.roughness = 0.1
	_box(root, Vector3(he.x * 1.7, he.y * 0.5, 0.06), Vector3(0, he.y * 0.85, -he.z * 0.95), glass).name = "Windshield"
	# Pritsche
	var bed := _box(root, Vector3(data.cargo_area_size.x * 1.04, 0.16, data.cargo_area_size.z * 1.02),
		Vector3(data.cargo_area_offset.x, he.y * 0.55, data.cargo_area_offset.z), mat_dark)
	bed.name = "CargoBed"
	# Seitenwände niedrig
	for side in [-1.0, 1.0]:
		var wall := _box(root, Vector3(0.08, data.cargo_area_size.y * 0.5, data.cargo_area_size.z),
			Vector3(data.cargo_area_offset.x + side * data.cargo_area_size.x * 0.52, he.y * 0.55 + data.cargo_area_size.y * 0.28, data.cargo_area_offset.z), mat_main)
		wall.name = "SideWall_%s" % ("L" if side < 0.0 else "R")
	_box(root, Vector3(data.cargo_area_size.x, data.cargo_area_size.y * 0.5, 0.08),
		Vector3(data.cargo_area_offset.x, he.y * 0.55 + data.cargo_area_size.y * 0.28, data.cargo_area_offset.z + data.cargo_area_size.z * 0.5), mat_main).name = "BackGate"
	# Stoßstangen
	_box(root, Vector3(he.x * 2.05, 0.18, 0.25), Vector3(0, -he.y * 0.15, -he.z - 0.12), mat_dark).name = "BumperF"
	_box(root, Vector3(he.x * 2.05, 0.18, 0.25), Vector3(0, -he.y * 0.15, he.z + 0.12), mat_dark).name = "BumperB"
	# Scheinwerfer + Bremslichter
	for side in [-1.0, 1.0]:
		var hl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.22, 0.14, 0.06)
		hl.mesh = bm
		var hlm := StandardMaterial3D.new()
		hlm.albedo_color = Color(1.0, 0.97, 0.8)
		hlm.emission_enabled = true
		hlm.emission = Color(1.0, 0.95, 0.75)
		hlm.emission_energy_multiplier = 3.0
		hl.material_override = hlm
		hl.position = Vector3(side * he.x * 0.7, he.y * 0.1, -he.z - 0.05)
		hl.name = "HeadL_%s" % ("L" if side < 0.0 else "R")
		hl.visible = false
		root.add_child(hl)
		var brake := MeshInstance3D.new()
		brake.mesh = bm.duplicate()
		var bm2 := StandardMaterial3D.new()
		bm2.albedo_color = Color(0.6, 0.05, 0.05)
		bm2.emission_enabled = true
		bm2.emission = Color(1.0, 0.05, 0.05)
		bm2.emission_energy_multiplier = 1.2
		brake.material_override = bm2
		brake.position = Vector3(side * he.x * 0.8, he.y * 0.05, he.z + 0.06)
		brake.name = "Brake_%s" % ("L" if side < 0.0 else "R")
		root.add_child(brake)
	# Paint-Fläche an Kabine+Pritsche: eigenes Overlay-Material auf Haupt-Meshes
	var paint_mat: ShaderMaterial = style.make_paint_material(primary, Vector3(he.x * 2.6, he.y * 2.2, he.z * 4.2)) if style != null else null
	if paint_mat != null:
		cabin.material_override = paint_mat
		bed.material_override = paint_mat
		var ps := PaintSurface.new()
		ps.name = "Paint"
		body.add_child(ps)
		ps.bind_material(paint_mat, Vector3(he.x * 2.6, he.y * 2.2, he.z * 4.2), Vector3(0, 0, -he.z * 0.2))
	# Licht-Knoten (SpotLight3D) an den HeadL angehängt
	for side in [-1.0, 1.0]:
		var light := SpotLight3D.new()
		light.name = "Light_%s" % ("L" if side < 0.0 else "R")
		light.spot_range = 26.0
		light.spot_angle = 34.0
		light.energy = 1.6
		light.position = Vector3(side * he.x * 0.7, he.y * 0.1, -he.z - 0.05)
		light.rotation_degrees = Vector3(-8, side * 6, 0)
		root.add_child(light)
	# Räder positionieren
	for i in 4:
		if i < data.wheel_positions.size():
			var wheels := body.get_node_or_null("Wheels") as Node3D
			if wheels != null and i < wheels.get_child_count():
				var w := wheels.get_child(i) as VehicleWheel
				if w != null:
					w.position = data.wheel_positions[i]
	return root

static func _style() -> StyleService:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Style") as StyleService

static func _fallback(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
