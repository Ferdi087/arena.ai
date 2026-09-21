extends Node
class_name RagdollController
## WACKEL-RAGDOLL (#60): jointe RigidBody-Limbs statt PhysicalBoneSimulator3D,
## weil wir (a) prozeduralen Character ohne importiertes Skelett haben und
## (b) mit PhysicalBoneSimulator3D-API-Namen zwischen 4.3/4.4/4.7 Vorsicht gilt
## (umbenannt/umgezogen). Für spätere GLB-Skins ist der alternative Pfad in
## ARCHITECTURE.md dokumentiert: Skeleton3D + PhysicalBoneSimulator3D mit
## reset_bones()/simulate Physics. Diese Implementierung läuft auf BEIDEN
## Physik-Engines identisch (nur Standard-Nodes).
##
## Flow: NORMAL -> IMPACT -> STAGGER -> RAGDOLL -> RECOVERY -> NORMAL.

const BODY_COUNT := 7  # Pelvis, Torso, Head, ArmL/R, LegL/R

@export var joint_stiffness: float = 6.0
@export var recovery_lerp: float = 9.0

var active: bool = false
var _bodies: Array[RigidBody3D] = []
var _joints: Array[PinJoint3D] = []
var _root: Node3D = null
var _rb_torso: RigidBody3D = null
var _player: Player = null
var _visual: Node3D = null
var _timer: float = 0.0
var _recovering: bool = false
var _pre_transform: Transform3D = Transform3D.IDENTITY

func bind(player: Player, visual_root: Node3D) -> void:
	_player = player
	_visual = visual_root
	set_physics_process(false)

func _ensure_built() -> void:
	if _root != null:
		return
	_root = Node3D.new()
	_root.name = "RagdollSet"
	add_child(_root)
	var specs := [
		# [name, local_pos, size, mass, parent_index]
		["Pelvis", Vector3(0, 0.95, 0), Vector3(0.34, 0.2, 0.24), 9.0, -1],
		["Torso", Vector3(0, 1.3, 0), Vector3(0.42, 0.52, 0.3), 14.0, 0],
		["Head", Vector3(0, 1.72, 0), Vector3(0.3, 0.3, 0.3), 5.0, 1],
		["ArmL", Vector3(-0.34, 1.36, 0), Vector3(0.13, 0.56, 0.13), 3.5, 1],
		["ArmR", Vector3(0.34, 1.36, 0), Vector3(0.13, 0.56, 0.13), 3.5, 1],
		["LegL", Vector3(-0.12, 0.5, 0), Vector3(0.15, 0.62, 0.15), 6.0, 0],
		["LegR", Vector3(0.12, 0.5, 0), Vector3(0.15, 0.62, 0.15), 6.0, 0],
	]
	for s in specs:
		var rb := RigidBody3D.new()
		rb.name = String(s[0])
		rb.mass = float(s[3])
		rb.collision_layer = 2
		rb.collision_mask = 1 | 4 | 8  # NICHT Player-Layer -> keine Selbstkollision
		rb.contact_monitor = true
		rb.max_contacts_reported = 4
		rb.freeze = true
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = s[2]
		cs.shape = box
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s[2]
		mi.mesh = bm
		mi.material_override = _limb_material()
		rb.add_child(mi)
		rb.position = s[1]
		_root.add_child(rb)
		_bodies.append(rb)
	# Verbindungen: Torso->Pelvis, Head->Torso, Arme->Torso, Beine->Pelvis
	var parents := [0, 0, 1, 1, 1, 0, 0]
	for i in range(1, _bodies.size()):
		var j := PinJoint3D.new()
		var rb := _bodies[i]
		var parent_rb: RigidBody3D = _bodies[parents[i]]
		j.name = "Joint%d" % i
		j.node_a = rb.get_path_to(parent_rb)
		j.node_b = rb.get_path()
		var local := rb.position - parent_rb.position
		j.position_a = local * 0.5
		j.position_b = local * -0.5
		j.exclude_nodes = true
		_root.add_child(j)
		_joints.append(j)
	_rb_torso = _bodies[1]
	_root.visible = false
	_set_all_freeze(true)

func _limb_material() -> StandardMaterial3D:
	var style := get_node_or_null(^"/root/Style") as StyleService
	if style != null:
		return style.get_flat_material(&"ragdoll_limb", Color(0.9, 0.32, 0.26))
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.32, 0.26)
	return m

func begin(duration: float = 1.2) -> void:
	if _player == null or active:
		return
	_ensure_built()
	active = true
	_recovering = false
	_timer = duration
	_pre_transform = _player.global_transform
	_root.visible = true
	_root.global_position = _player.global_position
	# Limbs relativ ausrichten + Schwung mitgeben:
	var fwd := -_player.global_transform.basis.z
	for rb in _bodies:
		rb.freeze = false
		rb.wake_up()
		rb.linear_velocity = _player.velocity * 0.65 + fwd * 0.4 + Vector3(0, 1.2, 0) * randf_range(0.0, 0.8)
		rb.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
	if _visual != null:
		_visual.hide()
	_player.set_collision_disabled_for_ragdoll(true)
	set_physics_process(true)
	# Impactsound (Hook für AudioManager)
	Sfx.impact_at(_player.global_position, &"soft", 0.6)

func _physics_process(delta: float) -> void:
	if not active:
		return
	if _timer > 0.0:
		_timer -= delta
		# Player-Wurzel folgt dem Torso -> Kamera greift weiter.
		if _rb_torso != null and _player != null:
			var tp := _rb_torso.global_position
			_player.global_position = Vector3(tp.x, _player.global_position.y, tp.z)
			_player.velocity = Vector3.ZERO
			_player.rotation.y = _rb_torso.global_rotation.y
		if _timer <= 0.0:
			_begin_recovery()
	elif _recovering:
		# Aufsteh-Phase: Limbs einsammeln, Visual zurückblenden.
		_set_all_freeze(true)
		_root.visible = false
		active = false
		_recovering = false
		if _visual != null:
			_visual.show()
		if _player != null:
			_player.set_collision_disabled_for_ragdoll(false)
			_player.global_transform = _pre_transform.translated(Vector3(0, 0.15, 0))
			_player._on_ragdoll_finished()
		set_physics_process(false)

func _begin_recovery() -> void:
	_recovering = true
	# Kurze "Steht taumelnd auf"-Verzögerung für Komik:
	await get_tree().create_timer(0.45).timeout
	if active:
		_set_all_freeze(true)

func _set_all_freeze(frz: bool) -> void:
	for rb in _bodies:
		rb.freeze = frz
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC if frz else RigidBody3D.FREEZE_MODE_STATIC
