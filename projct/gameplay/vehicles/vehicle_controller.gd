extends RigidBody3D
class_name VehicleController
## PHYSIK-TRUCK (#27/#62/#81/#82) – RigidBody3D + eigene Raycast-Suspension.
##
## Warum eigenes Federungs-Modell statt VehicleBody3D: Godot 4 Core besitzt
## keinen VehicleBody (Godot Jolt hätte JoltVehicle – aber dann wäre der Truck
## Jolt-ONLY). Unser Federkraft-Modell läuft auf BEIDEN Physik-Engines identisch
## und bildet genau das Gameplay ab, das #81 fordert:
##   Ladung -> Masse + Schwerpunkt -> Nicken/Wanken/Traktionsverlust.
##
## Node-Tree (vom Builder erzeugt, alles überschreibbar durch data.mesh_scene):
##   Truck (RigidBody3D, dieses Script)
##   ├── Collision (Box)
##   ├── BodyVisual (Node3D + Paint-Lack)      VehicleBuilder
##   ├── Paint (PaintSurface)                   Graffiti/Lack #84
##   ├── Wheels/FL,FR,RL,RR (VehicleWheel)
##   ├── Seats/Seat_0(Driver), Seat_1 (VehicleSeat + Interactable)
##   ├── CargoArea (cargo_area.gd)              Volumen + Verankerung + Strap-Logik
##   ├── BodyVisual/Lights...                   Scheinwerfer/Bremslicht
##   ├── ChaseCam (Node3D)
##   └── NetSync (MultiplayerSynchronizer)      Transform-Interpolation
##
## Netzwerk: HOST simuliert; Clients senden Steuer-Achsen an Autority.

const PHYS_DT := 1.0 / 60.0
const WHEEL_COUNT := 4

@export var data: VehicleData

var driver: Player = null
var passenger: Player = null
var vehicle_health: float = 100.0
var speed_kmh: float = 0.0
var lights_on: bool = false
var cargo_items: Array[FurnitureBody] = []
var _cargo_mass: float = 0.0
var _cargo_com: Vector3 = Vector3.ZERO
var _steer_input: float = 0.0
var _throttle: float = 0.0
var _brake: float = 0.0
var _handbrake: bool = false
var _wheels: Array[VehicleWheel] = []
var _cargo: CargoArea = null
var _upgrades_applied: bool = false
var _prev_vel: Vector3 = Vector3.ZERO
var _last_impact_msec: int = 0
var _horn_msec: int = 0

signal cargo_changed

func _ready() -> void:
	add_to_group("vehicles")
	add_to_group("saveable_vehicles")
	if data == null:
		data = Content.get_vehicle(&"starter_truck")
	_build()
	apply_upgrades()

func setup(vdata: VehicleData) -> void:
	data = vdata

# ------------------------------------------------------------------- Build --

func _build() -> void:
	if data == null:
		push_error("VehicleController ohne VehicleData – No-Op")
		set_physics_process(false)
		return
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	max_contacts_reported = 8
	contact_monitor = true
	angular_damp = 0.65
	linear_damp = 0.12
	mass = data.chassis_mass_kg
	if get_node_or_null("Collision") == null:
		var cs := CollisionShape3D.new()
		cs.name = "Collision"
		var box := BoxShape3D.new()
		box.size = data.body_half_extents * 2.0
		cs.shape = box
		add_child(cs)
	if get_node_or_null("BodyVisual") == null:
		add_child(VehicleBuilder.build(self, data))
	if get_node_or_null("Wheels") == null:
		var wheels_root := Node3D.new()
		wheels_root.name = "Wheels"
		add_child(wheels_root)
		for i in WHEEL_COUNT:
			var w := VehicleWheel.new()
			w.name = "Wheel_%d" % i
			w.index = i
			wheels_root.add_child(w)
			_wheels.append(w)
	if get_node_or_null("CargoArea") == null:
		_cargo = CargoArea.new()
		_cargo.name = "CargoArea"
		add_child(_cargo)
		_cargo.bind(self, data)
	if get_node_or_null("ChaseCam") == null:
		var cam := Node3D.new()
		cam.name = "ChaseCam"
		cam.position = Vector3(0.0, 2.6, -5.4)
		add_child(cam)
	if get_node_or_null("Seats") == null:
		var seats := Node3D.new()
		seats.name = "Seats"
		add_child(seats)
		for i in 2:
			var seat := VehicleSeat.new()
			seat.name = "Seat_%d" % i
			seat.seat_index = i
			seat.vehicle = self
			seat.position = Vector3(-0.42 if i == 0 else 0.42, 0.42, -0.9)
			seats.add_child(seat)

func apply_upgrades() -> void:
	if _upgrades_applied or data == null:
		return
	var eff: VehicleData = Company.effective_vehicle_data(data.id)
	if eff != null:
		data = eff
	_upgrades_applied = true

# --------------------------------------------------------------- Cargo API --

func add_cargo_item(body: FurnitureBody) -> void:
	if body in cargo_items:
		return
	cargo_items.append(body)
	recalc_cargo()
	EventBus.cargo_loaded.emit(self, body)

func remove_cargo_item(body: FurnitureBody) -> void:
	if cargo_items.erase(body):
		recalc_cargo()
		EventBus.cargo_unloaded.emit(self, body)

func recalc_cargo() -> void:
	var mass_sum := 0.0
	var com_sum := Vector3.ZERO
	var n := 0
	for item in cargo_items:
		if not is_instance_valid(item):
			continue
		mass_sum += item.mass
		com_sum += global_transform.basis.inverse().xform(item.global_position - global_position)
		n += 1
	if n > 0:
		com_sum /= float(n)
	_cargo_mass = mass_sum
	# Ladungshöhe schiebt den CoM hoch -> Wankneigung (#81). Wir dämpfen den
	# Hebelarm minimal, damit der Truck fahrbar bleibt (Priorität: Spielbarkeit).
	_cargo_com = Vector3(com_sum.x, com_sum.y * 0.6 + 0.25 * clampf(mass_sum / 800.0, 0.0, 1.0), com_sum.z) * 0.85
	call_deferred("_apply_mass")
	cargo_changed.emit()

func _apply_mass() -> void:
	mass = data.chassis_mass_kg + _cargo_mass

func total_load_kg() -> float:
	return _cargo_mass

func overladen() -> bool:
	return _cargo_mass > data.max_cargo_mass_kg

func load_ratio() -> float:
	return clampf(_cargo_mass / maxf(1.0, data.max_cargo_mass_kg), 0.0, 1.6)

func has_item(fid: StringName) -> bool:
	for it in cargo_items:
		if is_instance_valid(it) and it.data != null and it.data.id == fid:
			return true
	return false

# ------------------------------------------------------------- Input (Owner) --

func _physics_process(_delta: float) -> void:
	if driver == null:
		_steering_idle()
		return
	if not driver.is_authority():
		# Remote-Input -> an Autority senden; dort setzen *remote_input_rpc die Achsen.
		var s := _read_axis_pair("vehicle_steer_left", "vehicle_steer_right")
		var t := 1.0 if Input.is_action_pressed("vehicle_accelerate") else 0.0
		var b := 1.0 if Input.is_action_pressed("vehicle_brake") else 0.0
		if t > 0.0 or b > 0.0 or absf(s) > 0.01:
			remote_input.rpc_id(driver.get_multiplayer_authority(), s, t, b, Input.is_action_pressed("crouch"))
		_process_common()
		return
	_steering_input(
		_read_axis_pair("vehicle_steer_left", "vehicle_steer_right"),
		1.0 if Input.is_action_pressed("vehicle_accelerate") else 0.0,
		1.0 if Input.is_action_pressed("vehicle_brake") else 0.0,
		Input.is_action_pressed("crouch"))
	_process_common()
	if Input.is_action_just_pressed("vehicle_horn"):
		honk()
	if Input.is_action_just_pressed("exit_vehicle"):
		driver.exit_vehicle()

@rpc("any_peer", "call_remote", "unreliable_ordered")
func remote_input(steer: float, throttle: float, brake: float, hand: bool) -> void:
	if not is_authority():
		return
	_steering_input(steer, throttle, brake, hand)

func _read_axis_pair(neg_action: String, pos_action: String) -> float:
	var v := 0.0
	if Input.is_action_pressed(neg_action):
		v -= 1.0
	if Input.is_action_pressed(pos_action):
		v += 1.0
	return v

func _steering_idle() -> void:
	_throttle = 0.0
	_brake = 0.0
	_handbrake = false
	# Leerlauf:ROLL-Widerstand
	if absf(_steer_input) > 0.001:
		_steer_input = 0.0

func _steering_input(steer: float, throttle: float, brake: float, hand: bool) -> void:
	_steer_input = steer
	_throttle = throttle
	_brake = brake
	_handbrake = hand

func _process_common() -> void:
	pass

func is_authority() -> bool:
	if not Net.is_online():
		return true
	return multiplayer.is_server()

# ------------------------------------------------------------ Physik-Solver --

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if data == null:
		return
	var up: Vector3 = state.transform.basis.y
	var forward: Vector3 = -state.transform.basis.z
	var flat_forward := Vector3(forward.x, 0.0, forward.z)
	if flat_forward.length_squared() < 0.0001:
		return
	flat_forward = flat_forward.normalized()

	# 0) Ladungs-CoM -> Nick-/Wank-Torque (#81)
	if _cargo_mass > 1.0 and _cargo_com.length_squared() > 1e-6:
		var g := absf(ProjectSettings.get_setting("physics/3d/default_gravity"))
		var world_com := state.transform.basis.xform(_cargo_com)
		state.apply_torque_impulse(world_com.cross(Vector3(0.0, -g * _cargo_mass * PHYS_DT, 0.0)))

	# 1) Lenkeinschlag (weicher Einschwingweg) – positives Recht = RECHTS.
	var want_steer := _steer_input * deg_to_rad(data.steering_max_deg)
	var cur_steer := _cur_steer
	cur_steer = lerpf(cur_steer, want_steer, clampf(data.steering_speed * PHYS_DT, 0.0, 1.0))
	_cur_steer = cur_steer

	var v_forward := state.linear_velocity.dot(flat_forward)

	# 2) Räder
	var grounded := 0
	var wheel_impulse_total_normal := 0.0
	var wheel_positions: Array = []
	for i in WHEEL_COUNT:
		wheel_positions.append(data.wheel_positions[i] if i < data.wheel_positions.size() else Vector3(0, -0.1, 0))
	var suspension_rest := data.suspension_length
	var per_wheel_weight: float = mass * absf(ProjectSettings.get_setting("physics/3d/default_gravity")) / float(WHEEL_COUNT)
	var normal_per_wheel := 0.0
	for i in WHEEL_COUNT:
		var wloc: Vector3 = wheel_positions[i]
		var origin_world := state.transform.origin + state.transform.basis.xform(wloc + Vector3(0, suspension_rest * 0.55, 0))
		var ray_len := suspension_rest * 0.55 + suspension_rest + 0.1
		var hit := _ray_from_space(origin_world, origin_world + Vector3(0, -1, 0) * ray_len)
		var compression := 0.0
		var n_force := 0.0
		if not hit.is_empty():
			var ground_y: float = hit["position"].y
			var wheel_y: float = (state.transform.origin + state.transform.basis.xform(wloc)).y - data.wheel_radius
			var penetration: float = (ground_y + data.wheel_radius) - wheel_y
			compression = clampf(penetration, 0.0, suspension_rest)
			if compression > 0.001:
				grounded += 1
				var spring_f := data.suspension_stiffness * compression * mass * 0.9
				var rel_v: float = (state.linear_velocity + state.angular_velocity.cross(state.transform.basis.xform(wloc))).dot(Vector3.UP)
				var damp_f := -rel_v * data.damping_ratio * mass * 0.28
				n_force = clampf(spring_f + damp_f + per_wheel_weight * 0.0, 0.0, mass * 60.0)
				normal_per_wheel = maxf(normal_per_wheel, n_force)
				# Federkraft als Impuls nach oben
				state.apply_impulse(Vector3(0, 1, 0) * n_force * PHYS_DT,
					state.transform.origin + state.transform.basis.xform(wloc) - state.transform.origin)
		var w := _wheels[i] if i < _wheels.size() else null
		if w != null:
			w.update_visual(compression, -cur_steer if i < 2 else 0.0, v_forward / maxf(data.wheel_radius, 0.1), grounded > 0)
		# ---- Grip: Längs-/Seitenkraft mit Reibungskreis
		var wheel_pos_world := state.transform.origin + state.transform.basis.xform(wloc)
		var vel_at := state.linear_velocity + state.angular_velocity.cross(wheel_pos_world - state.transform.origin)
		var right_dir := state.transform.basis.xform(Vector3(1, 0, 0))
		right_dir = Vector3(right_dir.x, 0, right_dir.z).normalized()
		var fwd_axis := flat_forward
		if i < 2:
			fwd_axis = fwd_axis.rotated(Vector3.UP, -cur_steer)
			right_dir = right_dir.rotated(Vector3.UP, -cur_steer)
		var along := vel_at.dot(fwd_axis)
		var side := vel_at.dot(right_dir)
		var mu := data.base_grip
		if WeatherAccess.is_wet():
			mu *= 1.35 if Company.upgrades_for(data.id).has("tires_rain") else 0.55
		var load := n_force if n_force > 1.0 else per_wheel_weight
		var max_f := mu * load
		var drive := 0.0
		if grounded > 0 and i >= 2:
			drive = data.engine_power_n * _effective_throttle(v_forward)
		var brake_f := 0.0
		if _brake > 0.0:
			brake_f = -signf(along) * data.brake_power_n * 0.5
		var lat_f := clampf(-side * mass * 2.4, -max_f, max_f)
		var lon_f := clampf(drive + brake_f - along * mass * 0.9, -max_f * 1.2, max_f * 1.2)
		if _handbrake and i >= 2:
			lon_f *= 0.15
			lat_f *= 0.35
		wheel_impulse_total_normal += maxf(load, 0.0)
		var total_imp := (fwd_axis * lon_f + right_dir * lat_f) * PHYS_DT
		state.apply_impulse(total_imp, wheel_pos_world - state.transform.origin)

	# 3) Anti-Roll + Downforce + Luftstabilisierung
	if grounded >= 2:
		var roll_rate := state.angular_velocity.dot(-state.transform.basis.z)
		var anti := -roll_rate * data.anti_roll_stiffness * mass * 0.09
		state.apply_torque_impulse(state.transform.basis.x(Vector3(1, 0, 0)) * anti)
	var speed := state.linear_velocity.length()
	state.apply_impulse(Vector3(0, -1, 0) * (speed * speed * 0.00035 * mass))
	if grounded == 0:
		var ang := state.angular_velocity
		var damp_ang := ang * Vector3(0.96, 1.0, 0.96)
		state.angular_velocity = damp_ang

	# 4) Cap + Rückmeldung
	var vmax := (data.top_speed_kmh if v_forward >= 0.0 else maxf(data.reverse_speed_kmh, 12.0)) / 3.6
	if speed > vmax:
		state.linear_velocity = state.linear_velocity.limit_length(vmax * 1.05)
	speed_kmh = speed * 3.6

	# 5) Impact-Schaden (Fahrzeugschaden -> Reparaturkosten)
	var dv := (state.linear_velocity - _prev_vel).length()
	var now := Time.get_ticks_msec()
	if dv > 6.5 and now - _last_impact_msec > 240:
		_last_impact_msec = now
		apply_damage(clampf((dv - 6.5) * 1.6, 0.5, 40.0))
		_shake_cam(dv)
		Sfx.impact_at(global_position, &"metal", clampf(dv / 10.0, 0.4, 1.4))
	_prev_vel = state.linear_velocity

	# 6) seitliche G-Beschleunigung messen (für Ladungsrutscher)
	var right_world := state.transform.basis.xform(Vector3(1, 0, 0))
	var lat_dv := absf((state.linear_velocity - _prev_vel).dot(right_world))
	_accel_lat = lerpf(_accel_lat, lat_dv / PHYS_DT, 0.25)
	_check_cargo_slip(dv)

var _cur_steer: float = 0.0

func _effective_throttle(v_forward: float) -> float:
	if _throttle > 0.0:
		return _throttle
	if _brake > 0.0:
		# Bremsen -> bei Stand/roll: rückwärts
		if v_forward > 0.4:
			return -0.9   # motorbremsen/rückwärts-Schub (sanft)
		return -_brake
	return 0.0

func _check_cargo_slip(_dv: float) -> void:
	## Ladungssicherung (#82): ungesicherte Möbel rutschen ab ~6 m/s² seitlich.
	## CargoArea entscheidet über Strap-Stärke -> Eject = echtes Runterrutschen.
	if _accel_lat < 6.0:
		return
	for it in cargo_items.duplicate():
		if not is_instance_valid(it) or it.locked_in_cargo:
			continue
		var slip_chance := clampf((_accel_lat - 6.0) / 14.0, 0.0, 0.5)
		if randf() < slip_chance * PHYS_DT * 8.0:
			_cargo.eject_unsecured(it)

var _accel_lat: float = 0.0

func _ray_from_space(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4, [get_rid()])
	return space.intersect_ray(q)

# ------------------------------------------------------------------- misc --

func honk() -> void:
	if Time.get_ticks_msec() - _horn_msec < 400:
		return
	_horn_msec = Time.get_ticks_msec()
	var horn_set: StringName = &"horn_truck"
	if Company.upgrades_for(data.id).has("horn_air"):
		horn_set = &"horn_air"
	elif Company.upgrades_for(data.id).has("horn_organ"):
		horn_set = &"horn_organ"
	Sfx.play_world(global_position, horn_set, -2.0)

func set_lights(on: bool) -> void:
	lights_on = on
	var vis := get_node_or_null("BodyVisual")
	if vis != null:
		for c in vis.find_children("Head*", "*", true, false):
			(c as Node3D).visible = on

func apply_damage(points: float) -> void:
	var before := vehicle_health
	vehicle_health = clampf(vehicle_health - points, 0.0, 100.0)
	if not is_equal_approx(before, vehicle_health):
		EventBus.vehicle_damage_changed.emit(self, vehicle_health)
		if vehicle_health <= 0.0:
			UI.toast("%s ist Schrott – Werkstatt!" % data.display_name)

func repair_full() -> float:
	var cost := (100.0 - vehicle_health) * 14.0
	if cost <= 0.01:
		return 0.0
	if not Company.try_spend(cost, "Reparatur"):
		return -1.0
	vehicle_health = 100.0
	EventBus.vehicle_damage_changed.emit(self, vehicle_health)
	return cost

func take_control(player: Player) -> void:
	driver = player

func release_seat(index: int) -> void:
	match index:
		0:
			driver = null
		1:
			passenger = null

func get_seat_exit_transform(index: int) -> Transform3D:
	var side := -1.0 if index == 0 else 1.0
	var t := global_transform
	t.origin += t.basis.xform(Vector3(side * 1.9, 1.0, 0.0))
	var yaw := atan2(-t.basis.z.x, -t.basis.z.z)
	t.basis = Basis.from_euler(Vector3(0, yaw, 0))
	return t

func get_chase_transform(seat: int, yaw: float, pitch: float) -> Transform3D:
	var off := Vector3(0.0, 2.9, -6.0) if seat == 0 else Vector3(2.6, 2.5, -4.0)
	var origin := global_transform.origin + global_transform.basis.xform(off)
	var yaw_from_vehicle := atan2(-global_transform.basis.z.x, -global_transform.basis.z.z)
	var rot := Basis.from_euler(Vector3(pitch, yaw_from_vehicle + yaw, 0.0))
	return Transform3D(rot, origin)

func debug_info() -> String:
	return "%s | %.0f km/h | %.0f/%.0f kg | HP %.0f%%" % [
		data.display_name, speed_kmh, _cargo_mass, data.max_cargo_mass_kg, vehicle_health]

func get_save_data() -> Dictionary:
	return {
		"vehicle": String(data.id),
		"health": vehicle_health,
		"pos": [global_position.x, global_position.y, global_position.z],
		"rot_y": rotation.y,
	}

func apply_save_data(d: Dictionary) -> void:
	vehicle_health = float(d.get("health", 100.0))
	var p: Array = d.get("pos", [])
	if p.size() == 3:
		global_position = Vector3(p[0], p[1], p[2])
		rotation.y = float(d.get("rot_y", 0.0))
		_apply_mass()

func _shake_cam(strength: float) -> void:
	if driver != null:
		var rig := driver.get_rig()
		if rig != null:
			rig.add_shake(clampf(strength / 18.0, 0.0, 0.6))
