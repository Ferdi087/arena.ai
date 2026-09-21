extends RigidBody3D
class_name WorldDoor
## PHYSISCHES Türblatt mit HingeJoint (#99/#88): schwingt, schlägt zu, und bei
## massiver Kollision (zwei Spieler zerren am Sofa in der Tür) bricht sie aus
## den Angeln und wird zum freien Rigid Body. Emergent – kein Skript-Theater.

@export var open_deg: float = 95.0
@export var break_speed: float = 9.5
@export var auto_close: bool = true

var broken: bool = false
var _opened: bool = false
var _joint: HingeJoint3D = null
var _anchor: Node3D = null
var _auto_timer: float = 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1 | 2 | 4
	mass = 12.0
	angular_damp = 4.0
	if get_node_or_null("Interact") == null:
		var it := Interactable.new()
		it.name = "Interact"
		it.prompt_text = "Tür öffnen"
		it.action = &"toggle_door"
		it.handler = self
		add_child(it)
	if get_node_or_null("Collision") == null:
		var cs := CollisionShape3D.new()
		cs.name = "Collision"
		var box := BoxShape3D.new()
		box.size = Vector3(0.94, 2.05, 0.06)
		cs.shape = box
		cs.position = Vector3(0.47, 0, 0)
		add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.94, 2.05, 0.05)
		mi.mesh = bm
		var style := get_node_or_null(^"/root/Style") as StyleService
		if style != null:
			mi.material_override = style.get_flat_material(&"door_wood", Color(0.48, 0.32, 0.2))
		add_child(mi)
	if get_node_or_null("Anchor") == null:
		_anchor = Node3D.new()
		_anchor.name = "Anchor"
		add_child(_anchor)
	if get_node_or_null("Hinge") == null:
		# node_a = die RigidBody selbst (Anchor-Kind -> gelenkfixiert relativ),
		# Standard-Hinge-Setup für Scharniere ohne zweiten Körper.
		_joint = HingeJoint3D.new()
		_joint.name = "Hinge"
		_joint.node_a = NodePath("Anchor")
		_joint.node_b = NodePath("")        # "" => eigene RigidBody (Body-own joint)
		add_child(_joint)
	if _joint != null:
		_joint.use_lower_limit = true
		_joint.lower_limit = 0.0
		_joint.use_upper_limit = true
		_joint.upper_limit = deg_to_rad(open_deg)

func can_use(_player: Node) -> bool:
	return true

func do_use(_player: Node, _action: StringName) -> void:
	toggle()

func toggle() -> void:
	_opened = not _opened
	if broken:
		# Angeln "reparieren": Body kurz einfrieren + Joint zurücksetzen
		broken = false
		_joint.enabled = true
		_joint.use_upper_limit = true
		UI.toast("Tür wieder eingehängt.")
		return
	_auto_timer = 4.5
	if Net.is_online() and Net.is_authority():
		_swing.rpc(_opened)
	elif not Net.is_online():
		_swing(_opened)

@rpc("any_peer", "call_local", "reliable")
func _swing(open: bool) -> void:
	if not is_inside_tree():
		return
	_opened = open
	# Antriebs-Torque in Y – physisch, kein Teleport.
	var want_dir := 1.0 if open else 0.0
	var err := deg_to_rad(open_deg) * want_dir - wrapf(global_rotation.y - _base_rot(), -PI, PI)
	apply_torque_impulse(Vector3(0, clampf(err * 4.0, -6.0, 6.0), 0) * mass * 0.5)

func _base_rot() -> float:
	return 0.0

func _physics_process(delta: float) -> void:
	if broken:
		return
	if _opened and auto_close:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			toggle()
	if linear_velocity.length() > break_speed or angular_velocity.length() > 16.0:
		_break()

func _break() -> void:
	broken = true
	if _joint != null:
		_joint.enabled = false
		Sfx.play_world(global_position, &"wood_crack", -4.0)
		EventBus.random_event_triggered.emit(&"door_broken", {"pos": global_position})

func debug_label() -> String:
	return "door open=%s broken=%s" % [str(_opened), str(broken)]
