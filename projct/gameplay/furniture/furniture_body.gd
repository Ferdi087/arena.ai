extends RigidBody3D
class_name FurnitureBody
## MODULARER MÖBEL-KÖRPER (#36/#63/#110). Node-Tree (vom setup/_ready gebaut):
##
##   Furniture (RigidBody3D, dieses Script)
##   ├── Collision (CollisionShape3D)
##   ├── Visual (Node3D) – prozedural (FurnitureBuilder) ODER data.mesh_scene
##   ├── Damage (DamageComponent)
##   ├── Paint (PaintSurface, optional)
##   └── GrabPoints (Node3D-Kinder vom Typ GrabPoint)
##
## Grab-Solver: mehrere GrabHold-Instanzen -> gemeinsame Ziel-Pose (Co-Op-Lift).
## Gesteuert wird ÜBER GESCHWINDIGKEITEN im _integrate_forces-Hook – keine
## Teleportation, keine Joint-Explosionen, funktioniert identisch mit GodotPhys
## und Jolt (#31/#67/#130).

const PHYS_DT := 1.0 / 60.0  # Projekt-Setting: 60 Ticks/s – bewusst konstant.

@export var data: FurnitureData

var holds: Array[GrabHold] = []
var locked_in_cargo: bool = false
var delivered_untouched: bool = true
var damage_on_mission_start: float = 0.0

var _collision_shape: CollisionShape3D = null
var _visual_root: Node3D = null
var _paint: PaintSurface = null
var _damage: DamageComponent = null
var _last_strain: float = -1.0
var _com_offset: Vector3 = Vector3.ZERO

func setup(fdata: FurnitureData) -> void:
	data = fdata
	if data == null:
		push_error("FurnitureBody ohne FurnitureData – unsichtbarer No-Op-Modus.")
		return
	mass = clampf(data.mass_kg, 2.0, 4000.0)
	_com_offset = data.center_of_mass_offset
	continuous_cd = false
	max_contacts_reported = 8
	contact_monitor = true
	can_sleep = true
	collision_layer = 4          # Furniture
	collision_mask = 1 | 2 | 4 | 8  # World | Player | Furniture | Vehicle
	set_meta("furniture_data", data)
	set_meta("material_def", data.material)
	_build_children()

func _ready() -> void:
	add_to_group("furniture")
	if data != null and _collision_shape == null:
		_build_children()
	if not EventBus.damage_changed.is_connected(_on_damage_changed):
		EventBus.damage_changed.connect(_on_damage_changed)

func _build_children() -> void:
	if _visual_root != null or data == null:
		return
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = data.half_extents * 2.0
	_collision_shape.shape = box
	add_child(_collision_shape)

	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)
	if data.mesh_scene != null:
		_visual_root.add_child(data.mesh_scene.instantiate())
	else:
		FurnitureBuilder.build(self, data, _visual_root)

	_damage = DamageComponent.new()
	_damage.name = "Damage"
	add_child(_damage)

	if data.material == null or data.material.paintable:
		_paint = PaintSurface.new()
		_paint.name = "Paint"
		add_child(_paint)
		var pm := FurnitureBuilder.get_paint_material()
		if pm != null:
			_paint.bind_material(pm, data.half_extents * 2.0)
	# Standard-GrabPoints, falls none definiert (Modularität: Szenen können
	# zusätzliche GrabPoint-Kinder setzen -> automatisch bevorzugt).
	if find_grab_points().is_empty():
		for side in [-1.0, 1.0]:
			var gp := GrabPoint.new()
			gp.name = "GrabPoint_%s" % ("L" if side < 0.0 else "R")
			gp.position = Vector3(side * data.half_extents.x * 0.9, 0.1, 0.0)
			add_child(gp)

func find_grab_points() -> Array[GrabPoint]:
	var out: Array[GrabPoint] = []
	for c in get_children():
		if c is GrabPoint:
			out.append(c)
	for v in get_children():
		if v is Node3D and String(v.name) == "Visual":
			for c2 in v.get_children():
				if c2 is GrabPoint:
					out.append(c2)
	return out

# ------------------------------------------------------------- Grab-Interface --

func begin_hold(hold: GrabHold) -> void:
	holds.append(hold)
	if is_sleeping():
		wake_up()
	freeze = false
	locked_in_cargo = false
	EventBus.object_grabbed.emit(self, hold.player)

func end_hold(hold: GrabHold) -> void:
	holds.erase(hold)
	EventBus.object_released.emit(self, hold.player if hold != null else null)

func clear_holds() -> void:
	var players: Array = []
	for h in holds:
		players.append(h.player)
	holds.clear()
	for p in players:
		EventBus.object_released.emit(self, p)

func is_held() -> bool:
	return not holds.is_empty()

# ------------------------------------------------------------ Physik-Solver --

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# 1) Pseudo-Schwerpunkt: Gravitations-Drehmoment um den Daten-CoM-Offset.
	#    (Godot 4.x RigidBody3D bietet keinen portablen Public-CoM-Setter in
	#    Jolt+GodotPhys -> eigenes, deterministisches Gegen-Torque.)
	if _com_offset != Vector3.ZERO and state.linear_velocity.length() > 0.02:
		var world_off := state.transform.basis.xform(_com_offset)
		var gravity := Vector3(0.0, -absf(ProjectSettings.get_setting("physics/3d/default_gravity")), 0.0)
		state.apply_torque_impulse(world_off.cross(gravity * mass * PHYS_DT) * 0.5)

	# 2) Cargo-Freeze wird über freeze=true gelöst – hier nichts zu tun.
	if holds.is_empty():
		if _last_strain > 0.0:
			_last_strain = 0.0
			EventBus.grab_strain_changed.emit(self, 0.0)
		return

	# 3) Zielposition: alle Holds wollen ihren grip_local an ihrem socket_global.
	var target_pos := Vector3.ZERO
	var n := 0
	for h in holds:
		h.update_socket()
		target_pos += h.socket_global - state.transform.basis.xform(h.grip_local)
		n += 1
	if n == 0:
		return
	target_pos /= float(n)

	# 4) Ziel-Yaw: Co-Op aus Grip-Paaren, Solo aus Twist-Input.
	var target_yaw := rotation.y
	var haulers := _total_strength()
	var need := 1
	if data != null:
		need = maxi(data.required_haulers, 1)
	var ratio := clampf(haulers / float(need), 0.0, 2.0)
	var grip_pairs: Array = []
	for h in holds:
		grip_pairs.append([state.transform.origin + state.transform.basis.xform(h.grip_local), h.socket_global])
	if grip_pairs.size() >= 2:
		var body_vec: Vector3 = grip_pairs[0][0] - grip_pairs[1][0]
		var want_vec: Vector3 = grip_pairs[0][1] - grip_pairs[1][1]
		body_vec.y = 0.0
		want_vec.y = 0.0
		if body_vec.length_squared() > 0.0001 and want_vec.length_squared() > 0.0001:
			target_yaw = rotation.y + _signed_angle_xz(body_vec.normalized(), want_vec.normalized())
	else:
		target_yaw = rotation.y + holds[0].twist_delta

	# 5) strain: zu wenige Träger -> Limits runter, Objekt zieht Spieler fast runter.
	var strain := clampf(1.0 - ratio, 0.0, 1.0)
	if not is_equal_approx(strain, _last_strain):
		_last_strain = strain
		EventBus.grab_strain_changed.emit(self, strain)

	# 6) PD als Velocity-Control mit Force-Cap (kein Teleport, kein Jitter):
	var max_speed := lerpf(0.35, 3.6, clampf(ratio, 0.0, 1.0)) * _speed_scale()
	var desired_lin := (target_pos - global_position) * 12.0
	desired_lin.y *= 1.25
	desired_lin = desired_lin.limit_length(max_speed)
	var t := clampf(12.0 * PHYS_DT * (0.4 + 0.6 * ratio), 0.0, 0.85)
	state.linear_velocity = state.linear_velocity.lerp(desired_lin, t)

	# 7) Rotation: Y-Yaw-PD + sanfter Aufrecht-Hold. ECHTES Kippen entsteht beim
	#    Loslassen/Kollision – bewusst nicht beim Halten (Spielbarkeit #59).
	var yaw_err := wrapf(target_yaw - rotation.y, -PI, PI)
	var up := state.transform.basis.y
	var upright := up.dot(Vector3.UP)
	var desired_ang := Vector3.ZERO
	desired_ang.y = clampf(yaw_err * 10.0 * clampf(ratio, 0.35, 1.2), -6.0, 6.0)
	# Anti-Tilt als lokales Torque (schwach bei high strain -> Chaos erlaubt):
	var tilt_force := 0.0 if upright > 0.98 else (1.0 - clampf(upright, -1.0, 1.0)) * 14.0 * clampf(ratio, 0.05, 1.0)
	var axis := up.cross(Vector3.UP)
	if axis.length_squared() > 1e-5 and tilt_force > 0.0:
		state.apply_torque_impulse(state.transform.basis.inverse().xform(axis.normalized() * tilt_force) * mass * PHYS_DT)
	state.angular_velocity = state.angular_velocity.lerp(desired_ang, clampf(10.0 * PHYS_DT, 0.0, 0.45))

func _signed_angle_xz(a: Vector3, b: Vector3) -> float:
	return atan2(a.x * b.z - a.z * b.x, a.x * b.x + a.z * b.z)

func _total_strength() -> float:
	var s := 0.0
	for h in holds:
		s += h.strength
	return s

func _speed_scale() -> float:
	return clampf(lerpf(1.0, 0.45, clampf((mass - 60.0) / 540.0, 0.0, 1.0)), 0.35, 1.0)

# ------------------------------------------------------------ Cargo & Save --

func lock_in_cargo(anchor: Transform3D) -> void:
	clear_holds()
	locked_in_cargo = true
	freeze = true
	global_transform = anchor

func unlock_from_cargo() -> void:
	locked_in_cargo = false
	freeze = false

func set_damage_visual(t: float) -> void:
	if _paint != null and _paint.material != null:
		_paint.material.set_shader_parameter("damage_tint", t * 0.9)
	FurnitureBuilder.set_visual_damage(self, t)

func get_save_data() -> Dictionary:
	var d := {
		"fid": String(data.id) if data != null else "",
		"damage": _damage.damage_percent if _damage != null else 0.0,
		"untouched": delivered_untouched,
	}
	if _paint != null:
		var b64 := _paint.to_base64()
		if not b64.is_empty():
			d["paint"] = b64
	return d

func apply_save_data(d: Dictionary) -> void:
	if _damage != null:
		_damage.apply_save_data(d)
	if _paint != null and d.has("paint"):
		_paint.from_base64(String(d["paint"]))

func get_damage_percent() -> float:
	return _damage.damage_percent if _damage != null else 0.0

func debug_grab_info() -> String:
	return "holds=%d strain=%.2f mass=%.0f" % [holds.size(), _last_strain, mass]
