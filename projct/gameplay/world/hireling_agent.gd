extends Node3D
class_name HirelingAgent
## NPC-Mitarbeiter im Feld (#20/#21): wacklige Helfer, die Kartons/Möbel vom
## Einsatzort zum Truck tragen – mit EINBAUTEFFEHLERN: Fallwahrscheinlichkeit,
## Türen-Rempler, langsames Aufnehmen. Nutzt dieselbe Grab-Hold-Mechanik wie
## Spieler (GrabHold mit player=null, Strength nach Attributen) -> ein Solver
## für alles (#128).

enum Task { IDLE, WALK_TO_ITEM, CARRY_TO_TRUCK, RETURN, SWEEP }

var employee: EmployeeData = null
var world: WorldRoot = null
var state: int = Task.IDLE
var _visual: Node3D = null
var _carry: FurnitureBody = null
var _hold: GrabHold = null
var _target_pos: Vector3 = Vector3.ZERO
var _bob: float = 0.0
var _stuck_t: float = 0.0
var _sweep_target: Vector3 = Vector3.ZERO
var _enabled: bool = true

func setup(emp: EmployeeData, w: WorldRoot) -> void:
	employee = emp
	world = w
	add_to_group("npcs")
	_build_visual()

func _ready() -> void:
	add_to_group("npcs")
	if _visual == null:
		_build_visual()
	if world != null:
		_pick_next_job()

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var style := get_node_or_null(^"/root/Style") as StyleService
	var vest_col := Color(0.95, 0.7, 0.05)
	var pants_col := Color(0.2, 0.24, 0.32)
	_add_box(_visual, Vector3(0.4, 0.52, 0.26), Vector3(0, 1.06, 0), style.get_flat_material(&"hl_vest", vest_col) if style != null else null)
	_add_box(_visual, Vector3(0.28, 0.28, 0.26), Vector3(0, 1.48, 0), style.get_flat_material(&"hl_skin", Color(0.95, 0.75, 0.6)) if style != null else null)
	_add_box(_visual, Vector3(0.13, 0.55, 0.13), Vector3(-0.1, 0.42, 0), style.get_flat_material(&"hl_pants", pants_col) if style != null else null)
	_add_box(_visual, Vector3(0.13, 0.55, 0.13), Vector3(0.1, 0.42, 0), style.get_flat_material(&"hl_pants2", pants_col) if style != null else null)

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	if mat != null:
		mi.material_override = mat
	parent.add_child(mi)

func _physics_process(delta: float) -> void:
	if not _enabled or employee == null:
		return
	_bob += delta * (5.0 + (0.0 if _carry == null else 2.0))
	if is_instance_valid(_visual):
		_visual.rotation.z = sin(_bob * 0.9) * 0.11
	match state:
		Task.WALK_TO_ITEM:
			_walk_to(_target_pos, delta)
			if global_position.distance_to(_target_pos) < 1.4:
				_try_pickup()
		Task.CARRY_TO_TRUCK:
			_walk_to(_truck_pos(), delta, 0.85)
			_stuck_t += delta
			if _stuck_t > 3.2:
				_stumble()
				_stuck_t = 0.0
			if global_position.distance_to(_truck_pos()) < 2.6:
				_try_load()
			if _carry != null and not is_instance_valid(_carry):
				_state_reset()
		Task.RETURN:
			_walk_to(_target_pos, delta)
			if global_position.distance_to(_target_pos) < 2.0:
				state = Task.IDLE
		Task.SWEEP:
			_walk_to(_sweep_target, delta)
			if global_position.distance_to(_sweep_target) < 1.0:
				state = Task.IDLE
		_:
			_pick_next_job()

func _truck_pos() -> Vector3:
	var v := world.find_vehicle() if world != null else null
	if v == null:
		return global_position
	return v.global_position + Vector3(0, 0, v.data.cargo_area_offset.z if v.data != null else 2.0)

func _walk_to(target: Vector3, delta: float, speed_mult: float = 1.0) -> void:
	var to := target - global_position
	to.y = 0
	var d := to.length()
	if d < 0.4:
		return
	to = to.normalized()
	var speed := 2.2 * employee.move_speed_multiplier() * speed_mult
	global_position += to * speed * delta
	global_position.y = 0.0
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(9.0 * delta, 0.0, 1.0))

func _pick_next_job() -> void:
	state = Task.IDLE
	if world == null:
		return
	# 1) Möbel des aktiven Auftrags in Quellzone suchen
	if Missions.has_active_mission():
		var m := Missions.active_mission
		for b in get_tree().get_nodes_in_group("furniture"):
			var fb := b as FurnitureBody
			if fb == null or fb.is_held() or fb.locked_in_cargo or not is_instance_valid(fb):
				continue
			if fb.data == null:
				continue
			var wanted := false
			for f in m.furniture_manifest:
				if f.id == fb.data.id:
					wanted = true
					break
			if not wanted:
				continue
			var dist := fb.global_position.distance_to(global_position)
			if dist > 14.0 or fb.global_position.distance_to(_first_zone_pos()) > 18.0:
				continue
			_carry_target(fb)
			return
		# nix zu tragen -> fegen/sortieren (Chaos-Beschäftigung)
		if randf() < 0.3:
			_sweep()
	elif randf() < 0.05:
		_sweep()

func _first_zone_pos() -> Vector3:
	if world.mission_runtime != null and world.mission_runtime.mission_zone_source != null:
		return world.mission_runtime.mission_zone_source.global_position
	return Vector3.ZERO

func _carry_target(fb: FurnitureBody) -> void:
	_carry = fb
	state = Task.WALK_TO_ITEM
	_target_pos = fb.global_position

func _try_pickup() -> void:
	if _carry == null or not is_instance_valid(_carry):
		_state_reset()
		return
	if _carry.is_held():
		return
	var strength := lerpf(0.35, 1.0, clampf(employee.strength, 0.0, 1.0))
	_hold = GrabHold.new(null, _pick_grip_local(_carry), null, strength, 1)
	_hold.position_override = _fake_socket_update
	_carry.begin_hold(_hold)
	state = Task.CARRY_TO_TRUCK
	_stuck_t = 0.0

func _pick_grip_local(body: FurnitureBody) -> Vector3:
	if body.data == null:
		return Vector3(0, 0.2, 0)
	return Vector3(0, body.data.half_extents.y * 0.4, body.data.half_extents.z + 0.2)

func _fake_socket_update() -> void:
	# Der Socket IST der Hireling: Ziel = vor der Brust.
	var target := global_position + global_transform.basis.xform(Vector3(0, 1.25, 0.55))
	if _hold != null:
		_hold.socket_global = target

func _try_load() -> void:
	if _carry == null or not is_instance_valid(_carry):
		_state_reset()
		return
	var v := world.find_vehicle()
	var cargo := v.get_node_or_null("CargoArea") as CargoArea if v != null else null
	# Fall-Chance – MENSCHLICHER Faktor (#20):
	if randf() < employee.drop_chance():
		_carry.end_hold(_hold)
		_carry.apply_impulse(Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1)) * _carry.mass * 1.4)
		var dmg := _carry.get_node_or_null("Damage") as DamageComponent
		if dmg != null:
			dmg.apply_tool_damage(randf_range(6.0, 22.0), _carry.global_position, &"employee_drop")
		UI.toast("%s hat den %s fallen lassen!" % [employee.first_name, _carry.data.display_name if _carry.data != null else "Möbel"])
		_state_reset()
		return
	if v == null or cargo == null:
		_carry.end_hold(_hold)
		_state_reset()
		return
	_carry.end_hold(_hold)
	if not cargo.try_load(_carry):
		# voll -> zurücksetzen
		_state_reset()
		return
	state = Task.RETURN
	_target_pos = _first_zone_pos()
	_carry = null
	_hold = null

func _stumble() -> void:
	if randf() < 0.35 * (1.0 - employee.reliability):
		if _carry != null and is_instance_valid(_carry):
			_carry.apply_impulse(Vector3(0, 0, -1.2) * _carry.mass)
		_visual.rotation.x = 0.5
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if is_instance_valid(_visual):
				_visual.rotation.x = 0.0
		)

func _state_reset() -> void:
	if _hold != null and _carry != null and is_instance_valid(_carry):
		_carry.end_hold(_hold)
	_carry = null
	_hold = null
	state = Task.IDLE

func _sweep() -> void:
	state = Task.SWEEP
	_sweep_target = global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))

func set_enabled(e: bool) -> void:
	_enabled = e
