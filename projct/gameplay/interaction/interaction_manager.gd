extends Node
class_name InteractionManager
## INTERACTION MANAGER – zentrales Interaktions-Herz (Master-Prompt #66/#67/#68/#70).
##
## HÄNGT AN: Player unter  res://gameplay/player/player.tscn  als Kind "Interaction"
## (kein Autoload: alles ist pro-Spieler-Instanz + netzwerksicher pro Peer!).
##
## Zustandsautomat: IDLE -> DETECTING -> CANDIDATE -> GRABBING -> HOLDING
##                                                      (-> ROTATING) -> THROWING -> RELEASING
##
## Physik-Ansatz (bewusste Entscheidung statt Generic6DOFJoint, #31/#67):
##   Joint-Ketten neigen unter Godot/Jolt bei langen Hebelarmen + schwerer Last
##   zu Constraint-Jitter/Explosionen, besonders bei MULTI-GRAB zweier Spieler.
##   Deshalb: velocity-controlled PD-Solver IM KÖRPER (FurnitureBody.
##   _integrate_forces), hier nur Ziel-Ermittlung, Limits und Events.
##   => Kein Objekt wird je teleportiert, extreme Geschwindigkeiten werden
##      gecappt, und Co-Op-Holds addieren sich natürlich in einem Solver.
##
## Netzwerk (listen-server, #103/#114):
##   * Nur der OWNER dieses Managers führt Interaktionen aus.
##   * Grabs werden am SERVER registriert (RPC), der die Physik authoritativ
##     simuliert; Clients sehen Resultat über MultiplayerSynchronizer des
##     Körpers (interpoliert).
##   * Reinkommen/rausgehen: hold wird in player_left aufgeräumt.

enum GrabState { IDLE, DETECTING, CANDIDATE, GRABBING, HOLDING, ROTATING, THROWING, RELEASING }

const RAY_MASK := 0b0001_1111  # World|Player|Furniture|Vehicle|Interaction|NPC|Decoration|Trigger

@export_group("Feel (#68)")
@export var grab_distance: float = 3.4
@export var grab_strength: float = 1.0            # multipliziert auf GrabHold.strength
@export var sprint_strength_bonus: float = 1.15
@export var throw_impulse_factor: float = 3.2    # * player velocity auf released body
@export var max_throw_speed: float = 14.0        # Cap gegen Physik-Bombs
@export var rotate_speed_deg: float = 130.0
@export var paint_radius_base: float = 0.045     # uv-Fraktion am PaintProjector

@export_group("Detection")
@export var hover_sensitivity_frames: int = 2    # Flattern vermeiden

var state: GrabState = GrabState.IDLE
var hovered: Node = null
var interactable_hovered: Interactable = null
var active_hold: GrabHold = null
var active_body: FurnitureBody = null
var multi_holders_hint: int = 1

var _player: Player
var _ray: RayCast3D
var _socket: Node3D
var _hover_frames: int = 0
var _unhover_frames: int = 0
var _tools: ToolController = null
var _jitter_guard_velocity: float = 0.0

func _ready() -> void:
	_player = get_parent() as Player
	assert(_player != null, "InteractionManager muss Kind eines Player sein")
	_ray = _player.get_interaction_ray()
	_socket = _player.get_grab_socket()
	_tools = get_node_or_null("Tools") as ToolController
	set_physics_process(true)
	# Sauberer Zustand falls Netzspieler verschwindet (#102):
	EventBus.player_left.connect(_on_player_left)

func _physics_process(_delta: float) -> void:
	if not _player.input_enabled:
		_release_current()
		return
	_update_hover()
	_tool_tick()
	if _paint_accum > 0.0:
		_paint_accum -= _phys_dt()
		if _paint_accum <= 0.0:
			_flush_pending_paint()
	match state:
		GrabState.IDLE:
			if hovered != null:
				_enter(GrabState.CANDIDATE)
		GrabState.CANDIDATE:
			_tick_candidate()
		GrabState.GRABBING:
			_tick_grabbing()
		GrabState.HOLDING, GrabState.ROTATING:
			_tick_holding()
		GrabState.THROWING:
			_tick_throwing()
		_:
			pass

# ---------------------------------------------------------------- states --

func _enter(next: GrabState) -> void:
	state = next

func _flush_pending_paint() -> void:
	if _paint_accum > 0.0:
		_paint_accum = 0.0
		var s := get_tree().get_first_node_in_group("world")
		if s != null:
			for node in get_tree().get_nodes_in_group("paint_surfaces_dirty"):
				if node is PaintSurface:
					(node as PaintSurface).commit_frame()

func _update_hover() -> void:
	if _ray == null:
		return
	var collider: Object = null
	if _ray.is_colliding():
		collider = _ray.get_collider()
	# 1) Interactable (Türen, Computer, Shops) – findet Kind-Komponente:
	interactable_hovered = _find_interactable(collider)
	# 2) Grab-Ziel: FurnitureBody mit Bestätigung über Distanz + GrabPoints.
	var new_hover: Node = null
	if collider is FurnitureBody:
		var body := collider as FurnitureBody
		if not body.locked_in_cargo and _within_grab_range(body):
			new_hover = body
	if new_hover != null:
		_hover_frames += 1
		_unhover_frames = 0
		if _hover_frames >= hover_sensitivity_frames:
			if hovered != new_hover:
				hovered = new_hover
				EventBus.interaction_hover_changed.emit(hovered)
	elif collider == null:
		_unhover_frames += 1
		if _unhover_frames >= hover_sensitivity_frames * 3:
			_hover_frames = 0
			if hovered != null:
				hovered = null
				EventBus.interaction_hover_changed.emit(null)

func _find_interactable(collider: Object) -> Interactable:
	if collider == null or not (collider is Node):
		return null
	var node := collider as Node
	for c in node.get_children():
		if c is Interactable:
			var it := c as Interactable
			if it.is_available_for(_player):
				return it
	return null

func _tick_candidate() -> void:
	if hovered == null:
		_enter(GrabState.IDLE)
		return
	if GameInput.is_action_pressed_buffered("interact") and not (hovered is FurnitureBody):
		_try_interact()
	if Input.is_action_just_pressed("grab"):
		if _request_grab(hovered):
			_enter(GrabState.GRABBING)
	elif Input.is_action_just_pressed("interact") and hovered is FurnitureBody:
		_try_interact()

func _try_interact() -> void:
	if interactable_hovered != null:
		interactable_hovered.activate(_player)

func _tick_grabbing() -> void:
	if active_hold == null:
		_enter(GrabState.IDLE)
		return
	# Short "Aufheben"-Phase: wir lassen den PD-Solver machen, wechseln nach Stabilität.
	_jitter_guard_velocity += 1
	if _jitter_guard_velocity > 4:
		_enter(GrabState.HOLDING)

func _tick_holding() -> void:
	# Rotation (Q/E)
	var twist := 0.0
	if Input.is_action_pressed("grab_rotate_cw"):
		twist += deg_to_rad(rotate_speed_deg) * _phys_dt()
	if Input.is_action_pressed("grab_rotate_ccw"):
		twist -= deg_to_rad(rotate_speed_deg) * _phys_dt()
	if not is_zero_approx(twist):
		state = GrabState.ROTATING
	else:
		state = GrabState.HOLDING
	active_hold.twist_delta += twist
	active_hold.update_socket()
	# Halten?
	if not Input.is_action_pressed("grab") or Input.is_action_just_pressed("grab_release"):
		_enter(GrabState.THROWING if _is_fast_motion() else GrabState.RELEASING)

func _tick_throwing() -> void:
	_release_current(true)

func _release_current(throw_it: bool = false) -> void:
	if active_body == null or active_hold == null:
		_enter(GrabState.IDLE)
		return
	var target := active_body
	var hold := active_hold
	if Net.is_online():
		# Server macht's (Throw-Impuls gehört in die auth. Simulation):
		_release_grab_rpc.rpc_id(Net.server_peer_id(), target.get_path(), throw_it, _player.velocity * throw_impulse_factor)
	else:
		_execute_release(target, hold, throw_it)
	active_body = null
	active_hold = null
	_enter(GrabState.IDLE)

func _execute_release(body: FurnitureBody, hold: GrabHold, throw_it: bool) -> void:
	body.end_hold(hold)
	if throw_it:
		# Wurf = Spielerbewegung * Faktor + Blickanteil, hart gecappt (#67.7).
		var v := _player.velocity * 0.6 + _player.get_look_dir() * 2.2
		body.apply_impulse(v.limit_length(max_throw_speed) * throw_impulse_factor * body.mass * 0.25)

# ------------------------------------------------------------------ grab --

func _request_grab(body: FurnitureBody) -> bool:
	if body == null:
		return false
	if Net.is_online() and not Net.is_authority():
		_grab_request_rpc.rpc_id(Net.server_peer_id(), body.get_path())
		return true
	return _do_grab_server(body, _player)

func _do_grab_server(body: FurnitureBody, player: Player) -> bool:
	var grip := _resolve_grip_local(body)
	if grip == Vector3.INF:
		return false
	var strength := grab_strength * (sprint_strength_bonus if Input.is_action_pressed("sprint") else 1.0)
	var hold := GrabHold.new(player, grip, player.get_grab_socket(), strength, player.network_peer_id)
	body.begin_hold(hold)
	active_body = body
	active_hold = hold
	multi_holders_hint = body.holds.size()
	_jitter_guard_velocity = 0
	return true

func _resolve_grip_local(body: FurnitureBody) -> Vector3:
	# 1) Bevorzugter freier GrabPoint (für Co-Op-Lifts mit Rollen),
	# 2) sonst lokaler Hit-Punkt (leicht innen, damit Kollision nicht kratzt).
	var points := body.find_grab_points()
	var best: GrabPoint = null
	for gp in points:
		if gp.is_free_for(_player):
			if gp.is_primary or best == null:
				best = gp
	if best != null:
		return body.to_local(best.global_position)
	if _ray.is_colliding():
		var hit := _ray.get_collision_point()
		var nrm := _ray.get_collision_normal()
		var inner := hit - nrm * 0.06
		return body.to_local(inner)
	return Vector3.INF

@rpc("any_peer", "call_remote", "reliable")
func _grab_request_rpc(body_path: NodePath) -> void:
	if not Net.is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player := Net.get_player_by_peer(sender) as Player
	var body := get_node_or_null(body_path) as FurnitureBody
	if player == null or body == null:
		return
	_do_grab_server(body, player)

@rpc("any_peer", "call_remote", "reliable")
func _release_grab_rpc(body_path: NodePath, throw_it: bool, velocity_hint: Vector3) -> void:
	if not Net.is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player := Net.get_player_by_peer(sender) as Player
	var body := get_node_or_null(body_path) as FurnitureBody
	if body == null or player == null:
		return
	var hold: GrabHold = null
	for h in body.holds:
		if h.player == player:
			hold = h
			break
	if hold == null:
		return
	body.end_hold(hold)
	if throw_it:
		body.apply_impulse(velocity_hint.limit_length(max_throw_speed) * body.mass)

# ------------------------------------------------------------------- paint --

var _paint_accum: float = 0.0

func _tool_tick() -> void:
	if _tools == null:
		return
	_tools.tick(self)

func begin_paint_stroke(params: Dictionary) -> void:
	## Wird von ToolController gerufen, solange tool_use gehalten wird (#70).
	if not _ray.is_colliding():
		return
	var collider: Object = _ray.get_collider()
	var hit := _ray.get_collision_point()
	var nrm := _ray.get_collision_normal()
	if collider is FurnitureBody or (collider is Node3D and _has_paint_surface(collider as Node3D)):
		var surf := _find_paint_surface(collider as Node)
		if surf != null and collider is Node3D:
			var local_pos := (collider as Node3D).to_local(hit)
			var local_nrm := (collider as Node3D).global_transform.basis.inverse().xform(nrm)
			var record := surf.stroke_at_world(local_pos, local_nrm, params)
			if not record.is_empty():
				_paint_accum = 0.05
				if Net.is_online():
					_broadcast_stroke.rpc(collider.get_path(), record)
	elif _player != null and collider == _player:
		Characters.paint_on_character(_player, hit, nrm, params)
		if Net.is_online():
			_broadcast_self_stroke.rpc(record_for_self(params, hit, nrm))

func record_for_self(_params: Dictionary, _hit: Vector3, _nrm: Vector3) -> Dictionary:
	return {}

@rpc("any_peer", "call_local", "reliable")
func _broadcast_stroke(body_path: NodePath, record: Dictionary) -> void:
	var surf := _find_paint_surface(get_node_or_null(body_path) as Node)
	if surf != null:
		surf.replay_stroke(record)

@rpc("any_peer", "call_local", "reliable")
func _broadcast_self_stroke(record: Dictionary) -> void:
	if not record.is_empty():
		Characters.replay_character_stroke(record)

func _has_paint_surface(node: Node3D) -> bool:
	for c in node.get_children():
		if c is PaintSurface:
			return true
	return false

func _find_paint_surface(node: Node) -> PaintSurface:
	if node == null:
		return null
	for c in node.get_children():
		if c is PaintSurface:
			return c
	return null

# ---------------------------------------------------------------- utility --

func _is_fast_motion() -> bool:
	return _player.velocity.length() > 3.6 or Input.is_action_just_released("grab")

func _within_grab_range(body: FurnitureBody) -> bool:
	return body.global_position.distance_to(_player.global_position) <= grab_distance + body.data.half_extents.length() * 0.5

func _phys_dt() -> float:
	return PHYS_DT_CONST

const PHYS_DT_CONST := 1.0 / 60.0

func _on_player_left(_peer_id: int) -> void:
	#Netz-Mitarbeiter/Player weg -> Holds sauber lösen (#102), kein Crashed-Sofa.
	if active_body != null and active_hold != null and active_hold.network_id == _peer_id:
		_release_current(false)

func get_player() -> Player:
	return _player

func get_hit_local(body: Node3D) -> Vector3:
	if _ray != null and _ray.is_colliding():
		return body.to_local(_ray.get_collision_point())
	return Vector3.ZERO

func debug_grab_info() -> String:
	if active_body == null:
		return "kein Grab (hover=%s)" % (String(hovered.get_path()) if hovered != null else "null")
	return "%s | holds=%d | strain→solver" % [String(active_body.name), active_body.holds.size()]
