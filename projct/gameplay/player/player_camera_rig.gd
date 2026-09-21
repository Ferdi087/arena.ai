extends Node3D
class_name PlayerCameraRig
## Third-Person-Kamera mit Kollisionsarm, Look, Fahrzeug-Modus, Cycle-Modi.
## Maus-Look läuft über _unhandled_input (nur wenn Maus gefangen & Owner hat Input).
## Die RIG-ROTATION (yaw) ist die Quelle für Player-Bewegungsvektoren (#71).

enum CamMode { SHOULDER, BACK, FREE_HIGH }

@export var min_distance: float = 0.6
@export var max_distance: float = 4.6
@export var arm_length: float = 3.1
@export var mouse_sensitivity_base: float = 0.0026
@export var pitch_min_deg: float = -55.0
@export var pitch_max_deg: float = 70.0
@export var vehicle_follow_lerp: float = 6.0

var yaw: float = 0.0
var pitch: float = -0.12
var mode: int = CamMode.SHOULDER
var _camera: Camera3D = null
var _head: Node3D = null
var _owner_player: Player = null
var _vehicle_target: VehicleController = null
var _vehicle_seat: int = 0
var _distance: float = 3.1
var _shake: float = 0.0

func bind_camera(cam: Camera3D, head: Node3D) -> void:
	_camera = cam
	_head = head
	_owner_player = get_parent().get_parent() as Player  # Rig -> Head -> Player
	if _camera != null:
		_camera.current = true
		_camera.enabled = true

func get_yaw() -> float:
	return yaw

func get_pitch() -> float:
	return pitch

func get_camera() -> Camera3D:
	return _camera

func cycle_mode() -> void:
	mode = (mode + 1) % 3
	if _camera != null:
		_camera.fov = Settings.camera_fov + (14.0 if mode == CamMode.FREE_HIGH else 0.0)

func enter_vehicle_mode(v: VehicleController, seat: int) -> void:
	_vehicle_target = v
	_vehicle_seat = seat

func exit_vehicle_mode() -> void:
	_vehicle_target = null

func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if _owner_player == null:
		return
	if not _owner_player.input_enabled or _owner_player.control != Player.ControlState.ON_FOOT:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := mouse_sensitivity_base * Settings.mouse_sensitivity
		yaw -= event.relative.x * sens
		pitch -= event.relative.y * sens * (-1.0 if Settings.invert_y else 1.0)
		pitch = clampf(pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
	if event.is_action_pressed("cycle_camera"):
		cycle_mode()

func _physics_process(delta: float) -> void:
	if _camera == null:
		return
	if _owner_player != null and _owner_player.is_online_proxy:
		set_physics_process(false)
		return
	if _vehicle_target != null:
		# Fahrzeug-Kamera: weicher Follow hinter dem Truck (Chase-Cam)
		var want: Transform3D = _vehicle_target.get_chase_transform(_vehicle_seat, yaw, pitch)
		_global_transform_smooth_to(want, delta, vehicle_follow_lerp)
		_apply_shake(delta)
		return
	# Fuß: Kamera-Arm am Head-Pivot (Rotation kommt vom Rig, nicht vom Körper).
	if _head == null:
		return
	var rot := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var dir := rot * Vector3(0, 0, -1)
	var base_origin: Vector3 = _head.global_transform.origin
	if mode == CamMode.FREE_HIGH:
		base_origin += Vector3(0, 2.4, 0)
	var distance := _resolve_arm(base_origin, dir)
	var shoulder_off := rot.xform(Vector3(0.42 if mode == CamMode.SHOULDER else 0.0, 0.0, 0.0))
	var want_origin := base_origin + shoulder_off + dir * distance
	_global_transform_smooth_to(Transform3D(rot, want_origin), delta, 16.0)
	_apply_shake(delta)

func _resolve_arm(origin: Vector3, dir: Vector3) -> float:
	# Federnder Arm mit Kollision: Ziel nicht durch Wände, Rückholung ohne Hit.
	var space := get_world_3d().direct_space_state
	var to := origin + dir * max_distance
	var excludes: Array[RID] = []
	if _owner_player != null:
		excludes.append(_owner_player.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, to, 1 | 2 | 4 | 8, excludes)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var blocked := origin.distance_to(hit["position"]) - 0.22
		_distance = lerpf(_distance, clampf(blocked, min_distance, max_distance), 0.45)
	else:
		_distance = lerpf(_distance, max_distance, 0.28)
	return _distance

func _global_transform_smooth_to(want: Transform3D, delta: float, speed: float) -> void:
	var cur := _camera.global_transform
	var t := clampf(speed * delta, 0.0, 1.0)
	_camera.global_transform = Transform3D(cur.basis.slerp(want.basis, t), cur.origin.lerp(want.origin, t))

func _apply_shake(delta: float) -> void:
	if _shake > 0.001:
		_shake = maxf(0.0, _shake - delta * 1.8)
		var s := _shake * 0.08
		_camera.global_position += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
	if _camera != null and not is_equal_approx(_camera.fov, Settings.camera_fov + (14.0 if mode == CamMode.FREE_HIGH else 0.0)):
		_camera.fov = Settings.camera_fov + (14.0 if mode == CamMode.FREE_HIGH else 0.0)
