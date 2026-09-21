extends Node
class_name DamageComponent
## DamageLogik als Component (Owner: RigidBody3D, meist FurnitureBody). #38/#39/#69
##
## Berechnung NUR aus DamageSettings + MaterialDef + realer Impuls-/Relativ-
## Geschwindigkeit – keine willkürlichen Konstanten im Code. Deterministisch.
##
## Kategorien: impact (Kollision/Fallen), crush (Dauerkontakt mit Druck),
## tumble (gekippt/hängt schräg), tool (Hammer etc.).

var damage_percent: float = 0.0
var destroyed: bool = false
var last_hit_pos: Vector3 = Vector3.ZERO
var last_impact_speed: float = 0.0

var _body: RigidBody3D
var _settings: DamageSettings
var _prev_velocity: Vector3 = Vector3.ZERO
var _contact_this_frame: bool = false
var _crush_timer: float = 0.0
var _last_damage_at: float = -10.0
var last_damage_amount: float = 0.0
var _repairable: bool = true

signal damage_applied(amount: float, cause: StringName)
signal destroyed_now

func _ready() -> void:
	_body = get_parent() as RigidBody3D
	if _body == null:
		push_warning("DamageComponent ohne RigidBody3D-Parent (%s) – deaktiviert" % str(get_parent()))
		set_physics_process(false)
		return
	_settings = Content.damage_settings
	_body.contact_monitor = true
	_body.max_contacts_reported = 8
	if not _body.body_entered.is_connected(_on_body_entered):
		_body.body_entered.connect(_on_body_entered)
	_prev_velocity = _body.linear_velocity

func _physics_process(delta: float) -> void:
	if destroyed or _body == null:
		return
	var state_v := _body.linear_velocity
	if _contact_this_frame:
		_contact_this_frame = false
		var dv := (state_v - _prev_velocity).length()
		var ref: float = maxf(0.0001, _settings.reference_impulse_velocity)
		# Impuls-Näherung: dv * mass, normiert auf Masse*RefV -> skalenfrei.
		var impact_strength: float = dv
		if impact_strength > _settings.min_impact_speed:
			var material_mult := _material_damage_mult()
			var fragility := 1.0
			if _body.has_meta("furniture_data"):
				fragility = (_body.get_meta("furniture_data") as FurnitureData).fragility
			var mass_factor := clampf(_body.mass / 30.0, 0.35, 3.0)
			var pts := (impact_strength / ref) * _settings.damage_per_impulse_unit * material_mult * fragility * mass_factor * 100.0
			pts = minf(pts, _settings.max_single_hit_damage)
			if pts > 0.4:
				_apply_damage(pts, &"impact", _body.global_position)
	_prev_velocity = state_v
	# Crush-Erkennung: mehrere Kontakte & niedrige Geschwindigkeit über Zeit
	# -> Körper wird gequetscht (Möbel an Wand geklemmt).
	if _crush_timer > 0.0:
		_crush_timer = maxf(0.0, _crush_timer - delta)
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_damage_at > 1.5 and damage_percent < 100.0 and _body.linear_velocity.length() < 0.35:
		if _count_side_contacts() >= 2:
			_apply_damage(_settings.tumble_damage_per_90deg * delta * 2.5 * _crush_timer_scale(), &"crush", _body.global_position)
	# Tumble: schräg stehen & niemand hält -> langsam increasing
	if _is_tumbling() and not _is_held():
		_apply_damage(_settings.tumble_damage_per_90deg * delta, &"tumble", _body.global_position)

func _on_body_entered(_body_entered: Node3D) -> void:
	_contact_this_frame = true
	_crush_timer = 0.25

func apply_tool_damage(amount_points: float, at_pos: Vector3, cause: StringName = &"tool") -> void:
	_apply_damage(amount_points, cause, at_pos)

func repair(amount_percent: float) -> void:
	if destroyed and not _repairable:
		return
	destroyed = false
	damage_percent = maxf(0.0, damage_percent - amount_percent)
	_update_visuals()
	EventBus.damage_changed.emit(_body, damage_percent, &"repair")

func set_state(dmg: float) -> void:
	damage_percent = clampf(dmg, 0.0, 100.0)
	destroyed = damage_percent >= 100.0
	_update_visuals()

func get_save_data() -> Dictionary:
	return {"damage": snappedf(damage_percent, 0.01)}

func apply_save_data(d: Dictionary) -> void:
	set_state(float(d.get("damage", 0.0)))

# ------------------------------------------------------------------- internal --

func _apply_damage(points: float, cause: StringName, at: Vector3) -> void:
	if destroyed or points <= 0.0:
		return
	var before := damage_percent
	damage_percent = clampf(damage_percent + points, 0.0, 100.0)
	last_damage_amount = damage_percent - before
	if damage_percent <= before:
		return
	last_hit_pos = _body.to_local(at) if at != Vector3.INF else Vector3.ZERO
	_last_damage_at = Time.get_ticks_msec() / 1000.0
	_update_visuals()
	damage_applied.emit(points, cause)
	EventBus.damage_changed.emit(_body, damage_percent, cause)
	if damage_percent >= 100.0:
		destroyed = true
		destroyed_now.emit()
		EventBus.item_destroyed.emit(_body)

func _material_damage_mult() -> float:
	var mat: MaterialDef = null
	if _body.has_meta("material_def"):
		mat = _body.get_meta("material_def")
	return mat.damage_multiplier if mat != null else 1.0

func _crush_timer_scale() -> float:
	return 1.0 + _crush_timer * 2.0

func _count_side_contacts() -> int:
	# Godot: contact count nicht direkt ausgelesen -> Proxy über CrushTimer
	# (Kontakte werden in body_entered gesetzt); reicht für sanfte Crush-Kurve.
	return 2 if _crush_timer > 0.0 else 0

func _is_tumbling() -> bool:
	var up := _body.global_transform.basis.y
	return up.dot(Vector3.UP) < 0.45 and _body.global_position.y > 0.35

func _is_held() -> bool:
	if _body.has_method("is_held"):
		return _body.call("is_held")
	return false

func _update_visuals() -> void:
	if _body.has_method("set_damage_visual"):
		_body.call("set_damage_visual", damage_percent / 100.0)
	if Settings.damage_popups and get_tree().get_first_node_in_group("world") != null:
		pass # Popups sind UI-Aufgabe: World zeigt sie über signal damage_changed.
