extends Node3D
class_name EquipmentComponent
## Accessoires am Charakter (Hüte/Brillen/Rucksäcke) + PHYSIKALISCHE Teile
## (Schal) als Verlet-Kette mit Wind-/Inertia-Reaktion (#11/#26).
## Kein RigidBody-Zoo für Mode-Krimskrams: Verlet ist deterministisch billig
## und in Multiplayer-Szenen trivial zu rekonstruieren (nur Basis-Rot needed).

var _instances: Dictionary[StringName, Node] = {}
var _player: Player = null
var _scarf_points: PackedVector3Array = PackedVector3Array()
var _scarf_prev: PackedVector3Array = PackedVector3Array()
var _scarf_meshes: Array[MeshInstance3D] = []
var _scarf_owner: CosmeticData = null

func _ready() -> void:
	_player = get_parent().get_parent() as Player  # Equipment -> Body -> Player
	sync_from_data(Characters.current_character)
	EventBus.accessory_equipped.connect(_on_equipped)

func _on_equipped(slot: StringName, cosmetic: CosmeticData) -> void:
	# Slot-Belegung ist bei uns id-basiert; slot-Param bleibt für UI-Filter.
	sync_from_data(Characters.current_character)

func sync_from_data(c: CharacterData) -> void:
	if c == null:
		return
	# Alles abreißen, dann aus der Ausstattungs-Liste aufbauen (einfach & robust, #102).
	for k in _instances:
		var n := _instances[k]
		if is_instance_valid(n):
			n.queue_free()
	_instances.clear()
	_clear_scarf()
	for cid in c.equipped:
		var cos: CosmeticData = Content.get_cosmetic(cid)
		if cos == null:
			continue
		_equip(cos)

func _attach_point(node_name: StringName) -> Node3D:
	# Anker-Knoten im Visual (Head/Hips/Neck) oder Fallback: eigene Nodes.
	var body := _player.get_node_or_null("Body") as Node3D
	if body != null:
		var visual := body.get_node_or_null("CharacterVisual") as Node3D
		if visual != null:
			match node_name:
				&"Head":
					return _head_anchor(visual)
				&"Neck":
					return _head_anchor(visual)
				&"Torso":
					return visual
				&"Hips":
					return visual
				&"Feet":
					return visual
	return _player

func _head_anchor(visual: Node3D) -> Node3D:
	var head := visual.get_node_or_null("Head") as Node3D
	return head if head != null else visual

func _equip(cos: CosmeticData) -> void:
	var parent := _attach_point(cos.attach_node)
	var node := Node3D.new()
	node.name = "COS_" + String(cos.id)
	node.position = cos.local_offset
	parent.add_child(node)
	_instances[cos.id] = node
	_build_procedural(cos, node)
	if cos.is_physical and cos.physical_segments > 0:
		_setup_scarf(cos, parent)

func _build_procedural(cos: CosmeticData, parent: Node3D) -> void:
	var style := get_node_or_null(^"/root/Style") as StyleService
	var mat: StandardMaterial3D = style.get_flat_material(cos.id, cos.color, 0.55) if style != null else _fallback_mat(cos.color)
	match String(cos.procedural_style):
		"cap":
			_box(parent, Vector3(0.3, 0.12, 0.3), Vector3(0, 0.16, 0), mat)
			_box(parent, Vector3(0.16, 0.03, 0.2), Vector3(0, 0.13, 0.2), mat)
		"sombrero":
			_cyl(parent, 0.42, 0.045, Vector3(0, 0.18, 0), mat)
			_cyl(parent, 0.16, 0.14, Vector3(0, 0.25, 0), mat)
		"cowboy":
			_cyl(parent, 0.34, 0.035, Vector3(0, 0.18, 0), mat)
			_cyl(parent, 0.15, 0.15, Vector3(0, 0.25, 0), mat)
		"beanie":
			_cyl(parent, 0.2, 0.12, Vector3(0, 0.2, 0), mat)
			_ball(parent, 0.05, Vector3(0, 0.29, 0), mat)
		"santa":
			_cone(parent, 0.16, 0.3, Vector3(0, 0.3, 0), mat)
			_ball(parent, 0.06, Vector3(0, 0.46, 0), StandardMaterial3D.new())
		"glasses", "neon_glasses":
			_box(parent, Vector3(0.3, 0.06, 0.04), Vector3(0, 0.03, 0.16), mat)
		"headphones":
			_cyl(parent, 0.26, 0.03, Vector3(0, 0.1, 0), mat)
			_box(parent, Vector3(0.09, 0.12, 0.06), Vector3(-0.22, 0.0, 0), mat)
			_box(parent, Vector3(0.09, 0.12, 0.06), Vector3(0.22, 0.0, 0), mat)
		"vest":
			_box(parent, Vector3(0.47, 0.3, 0.34), Vector3(0, -0.22, 0), mat)
			_box(parent, Vector3(0.1, 0.05, 0.36), Vector3(0, -0.12, 0.0), mat)
		"overall":
			_box(parent, Vector3(0.44, 0.4, 0.32), Vector3(0, -0.18, 0), mat)
		"belt":
			_cyl(parent, 0.3, 0.07, Vector3(0, -0.45, 0), mat)
		"backpack":
			_box(parent, Vector3(0.3, 0.34, 0.16), Vector3(0, -0.16, -0.24), mat)
		"boots":
			_box(parent, Vector3(0.5, 0.3, 0.42), Vector3(0, 0.06, 0.05), mat)
		"mask":
			_box(parent, Vector3(0.31, 0.26, 0.06), Vector3(0, 0.02, 0.16), mat)
		"scarf":
			pass # wird über die Verlet-Kette gebaut
		_:
			_box(parent, Vector3(0.2, 0.2, 0.2), Vector3.ZERO, mat)

func _setup_scarf(cos: CosmeticData, parent: Node3D) -> void:
	_scarf_owner = cos
	var segs := clampi(cos.physical_segments, 3, 10)
	_scarf_points.resize(segs)
	_scarf_prev.resize(segs)
	for i in segs:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 0.075, 0.03)
		mi.mesh = bm
		var style := get_node_or_null(^"/root/Style") as StyleService
		mi.material_override = style.get_flat_material(&"scarf_seg", cos.color, 0.9) if style != null else _fallback_mat(cos.color)
		parent.add_child(mi)
		_scarf_meshes.append(mi)
	for i in segs:
		_scarf_points[i] = parent.global_position + Vector3(0, 1.45 - 0.09 * i, -0.12 - 0.04 * i)
		_scarf_prev[i] = _scarf_points[i]
	set_physics_process(true)

func _clear_scarf() -> void:
	for m in _scarf_meshes:
		if is_instance_valid(m):
			m.queue_free()
	_scarf_meshes.clear()
	_scarf_points.clear()
	_scarf_prev.clear()
	_scarf_owner = null
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if _scarf_points.size() < 3:
		return
	var anchor := _player.get_node_or_null("Body") as Node3D
	var anchor_pos := anchor.global_position + Vector3(0, 1.45, -0.1) if anchor != null else _player.global_position + Vector3(0, 1.45, -0.1)
	# Verlet mit Wind + Drag + Distanz-Constraints (2 Iterationen reichen).
	var wind := WeatherAccess.wind_at(_player.global_position)
	var gravity := Vector3(0, -14.0, 0)
	var dt2 := delta * delta
	for i in range(1, _scarf_points.size()):
		var p := _scarf_points[i]
		var v := (p - _scarf_prev[i]) * 0.985 + (gravity + wind) * dt2
		_scarf_prev[i] = p
		_scarf_points[i] = p + v
	# Wenn der Schal an einem Möbel "hängen bleibt": Punkt wird zum nächsten
	# Möbel-Collider gezogen statt frei zu flattern (Tür-Hänger-Humor, #88).
	for i in range(1, _scarf_points.size()):
		var n0 := _scarf_points[i - 1]
		var n1 := _scarf_points[i]
		var dir := n1 - n0
		var dist := dir.length()
		var rest := 0.095
		if dist > 0.0001:
			var corr := dir.normalized() * (dist - rest) * 0.5
			if i > 1:
				_scarf_points[i - 1] += corr
			_scarf_points[i] -= corr
	_scarf_points[0] = anchor_pos + Vector3(0, -0.02, 0)
	for i in _scarf_meshes.size():
		var m := _scarf_meshes[i]
		if not is_instance_valid(m):
			continue
		m.global_position = _scarf_points[i]
		if i + 1 < _scarf_points.size():
			m.look_at(_scarf_points[i + 1], Vector3.UP)

# ------- primitive helpers -------

func _fallback_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

func _cone(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material) -> void:
	# Godot 4 hat KEIN ConeMesh – Zylinder mit winzigem Top-Radius ist der korrekte Weg.
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.01
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

func _ball(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
