extends RefCounted
class_name FurnitureBuilder
## Prozeduraler Möbel-Builder: baut aus FurnitureData-HalfExtents eine ansehnliche
## Cartoon-Form (Kategorien-Boxen, Zylinder-Beine, Polster, Glasfront) und legt
## Paint-Material an. Wenn FurnitureData.mesh_scene gesetzt ist, wird NUR das
## benutzt -> 1:1 austauschbar gegen echte Assets (#123).

const PAINT_MAT_KEY := "paint_mat"

static func build(body: RigidBody3D, data: FurnitureData, visual: Node3D) -> void:
	visual.name = "Visual"
	var he := data.half_extents
	var mat := StyleService_hook(data)
	match String(data.category):
		"seating":
			_box(visual, "Base", Vector3(he.x * 2.0, he.y * 0.75, he.z * 2.0), Vector3(0, -he.y * 0.62, 0), mat)
			_box(visual, "Back", Vector3(he.x * 2.0, he.y * 0.9, he.z * 0.35), Vector3(0, he.y * 0.1, -he.z * 0.8), mat)
			_box(visual, "ArmL", Vector3(he.z * 0.35, he.y * 0.9, he.z * 1.6), Vector3(-he.x * 1.85, he.y * 0.05, 0), mat)
			_box(visual, "ArmR", Vector3(he.z * 0.35, he.y * 0.9, he.z * 1.6), Vector3(he.x * 1.85, he.y * 0.05, 0), mat)
			var cush := _accent_mat(data)
			_box(visual, "Cushion1", Vector3(he.x * 0.9, he.y * 0.28, he.z * 1.55), Vector3(-he.x * 0.5, -he.y * 0.05, 0.05), cush)
			_box(visual, "Cushion2", Vector3(he.x * 0.9, he.y * 0.28, he.z * 1.55), Vector3(he.x * 0.5, -he.y * 0.05, 0.05), cush)
		"storage":
			_box(visual, "Carcass", he * 2.0, Vector3.ZERO, mat)
			var front := _accent_mat(data)
			_box(visual, "DoorL", Vector3(he.x * 0.9, he.y * 1.7, 0.04), Vector3(-he.x * 0.5, 0, he.z + 0.02), front)
			_box(visual, "DoorR", Vector3(he.x * 0.9, he.y * 1.7, 0.04), Vector3(he.x * 0.5, 0, he.z + 0.02), front)
			_knob(visual, Vector3(-he.x * 0.12, 0, he.z + 0.07), front)
			_knob(visual, Vector3(he.x * 0.12, 0, he.z + 0.07), front)
		"electronics":
			_box(visual, "Panel", he * 2.0, Vector3.ZERO, mat)
			var screen := StandardMaterial3D.new()
			screen.albedo_color = Color(0.05, 0.06, 0.09)
			screen.emission_enabled = true
			screen.emission = Color(0.15, 0.4, 0.8)
			screen.emission_energy_multiplier = 0.4
			_box(visual, "Screen", Vector3(he.x * 1.7, he.y * 1.7, 0.02), Vector3(0, 0, he.z + 0.01), screen)
			_box(visual, "Stand", Vector3(he.x * 0.5, he.y * 0.16, he.z * 0.8), Vector3(0, -he.y - 0.02, 0), mat)
		"appliance":
			_box(visual, "Housing", he * 2.0, Vector3.ZERO, mat)
			_disc(visual, Vector3(he.x * 0.85, he.y * 0.85, 0.06), Vector3(0, -he.y * 0.1, he.z + 0.03), data)
		"table":
			_table(visual, data, mat)
		"bedroom":
			_box(visual, "Frame", he * 2.0, Vector3.ZERO, mat)
			_box(visual, "Mattress", Vector3(he.x * 1.9, he.y * 0.5, he.z * 1.9), Vector3(0, he.y * 0.55, 0), _accent_mat(data))
			_box(visual, "Pillow", Vector3(he.x * 0.8, 0.12, he.z * 0.35), Vector3(0, he.y * 0.95, -he.z * 0.7), StandardMaterial3D.new())
		"decor":
			_box(visual, "Body", he * 1.7, Vector3.ZERO, mat)
			_cyl(visual, "Neck", Vector3(he.x * 0.3, he.y * 0.5, he.z * 0.3), Vector3(0, he.y * 1.1, 0), mat)
		_:
			_box(visual, "Main", he * 2.0, Vector3.ZERO, mat)
			if String(data.category) == "generic":
				var seam := _accent_mat(data)
				_box(visual, "Tape", Vector3(he.x * 1.9, 0.035, he.z * 1.9), Vector3(0, he.y + 0.005, 0), seam)
	# Extra: Klavier-Saitenkasten etc. über size_class Feinschliff
	if data.id == &"piano":
		_box(visual, "Fallboard", Vector3(he.x * 1.9, he.y * 0.12, he.z * 0.6), Vector3(0, he.y * 0.55, he.z * 0.75), mat)
		_box(visual, "Keys", Vector3(he.x * 1.7, he.y * 0.16, 0.18), Vector3(0, he.y * 0.1, he.z + 0.09), StandardMaterial3D.new())
	# Glass-Einlagen (Aquarium/Vitrine) – rein visuell; Damage macht der Body
	if data.breakable_glass_area > 0.05:
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.55, 0.8, 0.9, 0.32)
		glass.roughness = 0.05
		_box(visual, "GlassFront", Vector3(he.x * 1.9, he.y * 1.6, 0.02), Vector3(0, 0, he.z + 0.01), glass)
	body.set_meta("visual_built", true)

static func StyleService_hook(data: FurnitureData) -> StandardMaterial3D:
	var style := Engine.get_main_loop().root.get_node_or_null("Style")
	var col := data.base_color
	if style != null:
		return style.call("get_flat_material", StringName("furn_%s" % data.id), col)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	return m

static func _accent_mat(data: FurnitureData) -> StandardMaterial3D:
	var style := Engine.get_main_loop().root.get_node_or_null("Style")
	if style != null:
		return style.call("get_flat_material", StringName("furnacc_%s" % data.id), data.accent_color, 0.85)
	var m := StandardMaterial3D.new()
	m.albedo_color = data.accent_color
	return m

static func _table(visual: Node3D, data: FurnitureData, mat: StandardMaterial3D) -> void:
	var he := data.half_extents
	_box(visual, "Top", Vector3(he.x * 2.0, he.y * 0.18, he.z * 2.0), Vector3(0, he.y * 0.85, 0), mat)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(visual, "Leg%d%d" % [sx, sz], Vector3(0.07, he.y * 1.7, 0.07), Vector3(sx * (he.x - 0.1), -he.y * 0.02, sz * (he.z - 0.1)), mat)

static func _box(parent: Node3D, n: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var bm := BoxMesh.new()
	bm.size = maxv3(size)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _cyl(parent: Node3D, n: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var cm := CylinderMesh.new()
	cm.top_radius = maxf(size.x, 0.02)
	cm.bottom_radius = cm.top_radius
	cm.height = maxf(size.y, 0.02)
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _disc(parent: Node3D, size: Vector3, pos: Vector3, data: FurnitureData) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = maxf(size.x * 0.5, 0.05)
	cm.bottom_radius = cm.top_radius
	cm.height = 0.05
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.position = pos
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.4, 0.45, 0.5, 0.5)
	mi.material_override = glass
	parent.add_child(mi)

static func _knob(parent: Node3D, pos: Vector3, mat: Material) -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

static func maxv3(v: Vector3) -> Vector3:
	return Vector3(maxf(v.x, 0.01), maxf(v.y, 0.01), maxf(v.z, 0.01))

## Paint-Material fürs Gesamte (auf den Haupt-Body gemappt)
static func get_paint_material() -> ShaderMaterial:
	var style := Engine.get_main_loop().root.get_node_or_null("Style")
	if style != null:
		return style.call("make_paint_material", Color(1, 1, 1, 1), Vector3.ONE)
	return null

## Damage -> optisch: dunkler + "cracks" über Decal-Ersatz (zweite Mesh-Schicht?
## Performance: wir nutzen material tint nur, das Reiben-Feeling kommt aus Audio).
static func set_visual_damage(body: RigidBody3D, t: float) -> void:
	for c in body.get_children():
		if c is MeshInstance3D:
			var m := (c as MeshInstance3D).material_override
			if m != null and m.has_method("set") and m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter("damage_tint", t * 0.9)
		elif c is Node3D and String(c.name) == "Visual":
			for m2 in c.get_children():
				if m2 is MeshInstance3D and m2.material_override is StandardMaterial3D:
					var sm := m2.material_override as StandardMaterial3D
					sm.albedo_color = sm.albedo_color.darkened(t * 0.35)
