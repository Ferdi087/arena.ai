extends CharacterBody3D
class_name Player
## SPIELER (CharacterBody3D) – Node-Tree (im Code gebaut, #108):
##
##   Player (CharacterBody3D)              layer=Player, mask=World|Furniture|Vehicle|NPC
##   ├── Collision (CollisionShape3D, Kapsel)
##   ├── Body (Node3D)                     – "Visual-Root", bekommt Wobble/Lean
##   │   ├── CharacterVisual (character_visual.gd)   prozedural + PaintSurface
##   │   └── Equipment (equipment_component.gd)      Accessoires/Physik-Schal
##   ├── HeadPivot (Node3D)
##   │   ├── Camera3D + PlayerCameraRig (player_camera_rig.gd)
##   │   └── InteractRay (RayCast3D, mask=ALLE|Trigger)
##   ├── GrabSocket (Node3D)               – Ziel-Socket für FurnitureBody-PD
##   ├── Ragdoll (ragdoll_controller.gd)   – Physically-jointed Fallback-Ragdoll
##   ├── Interaction (interaction_manager.gd)
##   │   └── Tools (tool_controller.gd)
##   └── NetSync (MultiplayerSynchronizer) – Position/Rotation/Velocity/Lean
##
## Design: Gameplay-Movement != Visual-Wobble != Ragdoll != Animation (#59).
## Steuerung bleibt PREZISE (accel/fric-Modell), das WACKELN passiert nur in
## Body/HeadPivot/Ragdoll – nie in der Kollision.

const PHYS_DT := 1.0 / 60.0

@export var walk_speed: float = 4.4
@export var sprint_speed: float = 6.6
@export var accel_ground: float = 42.0
@export var accel_air: float = 8.0
@export var friction_ground: float = 16.0
@export var jump_velocity: float = 5.2
@export var gravity_scale: float = 1.0
@export var max_push_mass: float = 900.0        # schieben von Möbeln
@export var strength_base: float = 1.0

enum ControlState { ON_FOOT, IN_VEHICLE, RAGDOLL, LOCKED }
var control: ControlState = ControlState.ON_FOOT
var input_enabled: bool = true
var vehicle: VehicleController = null
var player_index: int = 0                       # lokaler Split-Index
var network_peer_id: int = 1
var display_name: String = "PLAYER 1"
var is_online_proxy: bool = false

var _body_node: Node3D
var _visual: CharacterVisual = null
var _head: Node3D
var _camera: Camera3D = null
var _rig: PlayerCameraRig = null
var _ray: RayCast3D = null
var _socket: Node3D
var _ragdoll: RagdollController = null
var _interaction: InteractionManager = null
var _wobble_t: float = 0.0
var _lean: float = 0.0
var _stumble: float = 0.0
var _spawn_transform: Transform3D = Transform3D.IDENTITY
var _last_safe_pos: Vector3 = Vector3.ZERO

signal state_changed(new_state: ControlState)

func _ready() -> void:
	add_to_group("players")
	_build()
	set_multiplayer_authority(network_peer_id if multiplayer.has_multiplayer_peer() else 1)

## Wurzel-Node-Struktur wird im Code gebaut, damit Player-Instanziierung ohne
## .tscn-Asset-Dauer funktioniert; jedes Kind bleibt aber Editor-überschreibbar
## (falls später player.tscn gepflegt wird, prüft _build auf vorhandene Kinder).
func _build() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | 8 | 32   # World|Furniture|Vehicle|NPC
	_last_safe_pos = global_position
	if get_node_or_null("Collision") == null:
		var col := CollisionShape3D.new()
		col.name = "Collision"
		var cap := CapsuleShape3D.new()
		cap.radius = 0.32
		cap.height = 1.7
		col.shape = cap
		add_child(col)
	_body_node = get_node_or_null("Body") as Node3D
	if _body_node == null:
		_body_node = Node3D.new()
		_body_node.name = "Body"
		add_child(_body_node)
	if _body_node.get_node_or_null("CharacterVisual") == null:
		_visual = CharacterVisual.new()
		_visual.name = "CharacterVisual"
		_body_node.add_child(_visual)
	if _body_node.get_node_or_null("Equipment") == null:
		var eq := EquipmentComponent.new()
		eq.name = "Equipment"
		_body_node.add_child(eq)
	_head = get_node_or_null("HeadPivot") as Node3D
	if _head == null:
		_head = Node3D.new()
		_head.name = "HeadPivot"
		_head.position = Vector3(0, 1.52, 0)
		add_child(_head)
	if _head.get_node_or_null("Camera3D") == null:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		_camera.fov = Settings.camera_fov
		_head.add_child(_camera)
		_rig = PlayerCameraRig.new()
		_rig.name = "Rig"
		_head.add_child(_rig)
		_rig.bind_camera(_camera, _head)
	if _head.get_node_or_null("InteractRay") == null:
		_ray = RayCast3D.new()
		_ray.name = "InteractRay"
		_ray.target_position = Vector3(0, 0, -4.2)
		_ray.collision_mask = 255
		_ray.collide_with_areas = false
		_head.add_child(_ray)
		_ray.add_exception(self)
	_socket = get_node_or_null("GrabSocket") as Node3D
	if _socket == null:
		_socket = Node3D.new()
		_socket.name = "GrabSocket"
		_socket.position = Vector3(0, 1.18, 0.85)
		add_child(_socket)
	if get_node_or_null("Ragdoll") == null:
		_ragdoll = RagdollController.new()
		_ragdoll.name = "Ragdoll"
		add_child(_ragdoll)
		_ragdoll.bind(self, _body_node)
	if get_node_or_null("Interaction") == null:
		_interaction = InteractionManager.new()
		_interaction.name = "Interaction"
		add_child(_interaction)
		var tools := ToolController.new()
		tools.name = "Tools"
		_interaction.add_child(tools)
	_spawn_transform = global_transform
	if is_online_proxy:
		_setup_net_sync()

func _setup_net_sync() -> void:
	## Remote-Player-Instanzen werden von WorldRoot/Spawner mit is_online_proxy
	## erzeugt. Sync: rein interpolativ, keine Autonomie (input_enabled=false).
	input_enabled = false
	if _camera != null:
		_camera.enabled = false
	var sync := MultiplayerSynchronizer.new()
	sync.name = "NetSync"
	var cfg := SceneReplicationConfig.new()
	var self_path := NodePath(".")
	cfg.add_property(self_path, "position", SceneReplicationConfig.PROPERTY_MODE_ALWAYS)
	cfg.add_property(self_path, "rotation", SceneReplicationConfig.PROPERTY_MODE_ALWAYS)
	cfg.add_property(self_path, "velocity", SceneReplicationConfig.PROPERTY_MODE_ALWAYS)
	sync.replication_config = cfg
	sync.replication_interval = 0.07
	add_child(sync)

# ---------------------------------------------------------------- Input/Move --

func _physics_process(delta: float) -> void:
	match control:
		ControlState.ON_FOOT:
			_foot_physics(delta)
		ControlState.RAGDOLL:
			pass # RagdollController macht die Show
		_:
			# IN_VEHICLE/LOCKED: Kinematik am Fahrzeug; keine eigene Schwerkraft.
			velocity = Vector3.ZERO
			move_and_slide()
	_apply_wobble(delta)
	_stumble = maxf(0.0, _stumble - delta * 2.4)
	# "Sicherer Zustand" bei Fall in die Stadt-Lücke (#102)
	if global_position.y < -25.0:
		global_position = _last_safe_pos
		velocity = Vector3.ZERO
	if is_on_floor() and velocity.length() < 0.6:
		_last_safe_pos = global_position

func _foot_physics(delta: float) -> void:
	var move_input := GameInput.movement_vector(player_index)
	var input_locked: bool = not input_enabled or (interaction_active_grab_lock())
	var dir := Vector3.ZERO
	if not input_locked and move_input.length_squared() > 0.0:
		var cam_yaw := _rig.get_yaw() if _rig != null else rotation.y
		var f := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var r := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		dir = (r * move_input.x + f * -move_input.y).normalized()
	var sprinting := Input.is_action_pressed("sprint") and dir.length_squared() > 0.01
	var target_speed := sprint_speed if sprinting else walk_speed
	if control == ControlState.ON_FOOT and _interaction != null and _interaction.state == _interaction.GrabState.HOLDING:
		target_speed *= 0.72  # tragen macht langsam – gewollt
	# Beschleunigungsmodell (präzises Stop & Go + Luftkontrolle)
	var accel := accel_ground if is_on_floor() else accel_air
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	if dir.length_squared() > 0.0:
		horizontal = horizontal.move_toward(dir * target_speed, accel * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, friction_ground * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity.y -= absf(ProjectSettings.get_setting("physics/3d/default_gravity")) * gravity_scale * delta
	if is_on_floor() and velocity.y < 0.1:
		velocity.y = maxf(velocity.y, -0.1)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not input_locked:
		velocity.y = jump_velocity
		# Sprung-Wobble ins Visual
		if _visual != null:
			_visual.play_jump_squash()
	move_and_slide()
	# Richtung: weich in Blickrichtung der Bewegung
	if dir.length_squared() > 0.01:
		var want_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, want_yaw, clampf(14.0 * delta, 0.0, 1.0))
	# Auto-Push gegen schwere Physikobjekte (Umzugsshove!)
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider()
		if other is RigidBody3D:
			var rb := other as RigidBody3D
			if rb.mass <= max_push_mass and rb.mass > 0.5:
				var push := (rb.global_position - global_position)
				push.y = 0
				rb.apply_impulse(push.normalized() * minf(rb.mass, 220.0) * delta * 14.0)

func interaction_active_grab_lock() -> bool:
	# Greif-Bewegung bleibt möglich (Präzision vor "Realismus").
	return false

# ------------------------------------------------------------------ Wobble --

func _apply_wobble(delta: float) -> void:
	if _body_node == null:
		return
	_wobble_t += delta * (2.0 + velocity.length() * 0.9)
	var speed_f := clampf(velocity.length() / sprint_speed, 0.0, 1.2)
	var target_lean := 0.0
	if is_on_floor():
		target_lean = -speed_f * 0.16
	_lean = lerpf(_lean, target_lean, clampf(8.0 * delta, 0.0, 1.0))
	var wobble := Vector3(
		sin(_wobble_t * 6.0) * 0.028 * (0.35 + speed_f),
		0.0,
		cos(_wobble_t * 3.0) * 0.045 * (0.25 + speed_f * 0.9) + _lean * 0.5 + _stumble
	)
	_body_node.rotation = wobble
	if _head != null:
		_head.rotation.x = _rig.get_pitch() if _rig != null else 0.0
		_head.rotation.z = wobble.z * 0.6

func _on_impact(strength: float, _pos: Vector3) -> void:
	## Aufgerufen vom CharacterVisual/Floor-Check oder GrabStrain (siehe Hooks).
	if strength > 5.2 and is_on_floor() and control == ControlState.ON_FOOT:
		_stumble = clampf(strength * 0.05, 0.05, 0.5) * (1.0 if randf() > 0.5 else -1.0)
		if strength > 9.5:
			_ragdoll.begin(lerpf(0.6, 1.8, clampf(strength / 16.0, 0.0, 1.0)))

# ------------------------------------------------------------------- API --

func get_interaction_ray() -> RayCast3D:
	return _ray

func get_grab_socket() -> Node3D:
	return _socket

func get_look_dir() -> Vector3:
	if _camera != null and _camera.global_transform.basis.z.length_squared() > 0.0:
		return -_camera.global_transform.basis.z.normalized()
	return -global_transform.basis.z.normalized()

func get_visual() -> CharacterVisual:
	return _visual

func get_main_camera() -> Camera3D:
	return _camera

func get_rig() -> PlayerCameraRig:
	return _rig

func get_head() -> Node3D:
	return _head

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled

func set_collision_disabled_for_ragdoll(disabled: bool) -> void:
	## Während des Ragdolls darf der CharacterBody kein Kollider sein
	## (die Limbs simulieren sonst gegen sich selbst).
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col != null:
		col.disabled = disabled
	collision_layer = 0 if disabled else 2

func enter_vehicle(v: VehicleController, seat_index: int) -> void:
	if control != ControlState.ON_FOOT:
		return
	control = ControlState.IN_VEHICLE
	state_changed.emit(control)
	vehicle = v
	set_physics_process(false)
	if _visual != null:
		_visual.visible = false
	if _rig != null:
		_rig.enter_vehicle_mode(v, seat_index)
	EventBus.player_entered_vehicle.emit(v, self)

func exit_vehicle() -> void:
	if control != ControlState.IN_VEHICLE or vehicle == null:
		return
	var v := vehicle
	var drop := v.get_seat_exit_transform(player_index)
	global_transform = drop
	control = ControlState.ON_FOOT
	state_changed.emit(control)
	v.release_seat(player_index)
	vehicle = null
	set_physics_process(true)
	if _visual != null:
		_visual.visible = true
	if _rig != null:
		_rig.exit_vehicle_mode()
	EventBus.player_exited_vehicle.emit(v, self)

func begin_ragdoll(duration: float = 1.1) -> void:
	if control == ControlState.IN_VEHICLE:
		return
	control = ControlState.RAGDOLL
	state_changed.emit(control)
	_ragdoll.begin(duration)

func _on_ragdoll_finished() -> void:
	if control == ControlState.RAGDOLL:
		control = ControlState.ON_FOOT
		state_changed.emit(control)

func set_active_camera_for_viewport(vp: Viewport) -> void:
	if _camera != null:
		_camera.enabled = false
		if vp != null:
			vp.add_child(_camera)
			_camera.current = true

func cycle_camera_mode() -> void:
	if _rig != null:
		_rig.cycle_mode()

func is_authority() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server() or get_multiplayer_authority() == multiplayer.get_unique_id()
