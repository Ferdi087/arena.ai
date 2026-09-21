extends Node
class_name MissionRuntime
## MISSIONS-LAUFZEIT in der Welt-Szene (#115/#128). Kein Mission-Spezial-Code:
## Special-Missionen = Regeln auf diesem Runtime-Gerüst:
##   haunted        -> Poltergeist-Impulse + Türen
##   weight_balancing-> Truck-Warnungen (Load-Check im Objective "load_vehicle")
##   crane/high_wind -> Windkraft auf Halde-Objekte verdoppelt
##   messy_hoard    -> Extra-Kleinkram-Spawns
## Objectives werden hier getickt, Damage getrackt, Payout via PayoutCalculator.

@export var world: Node

var tracking_items: Dictionary[String, float] = {}   # fid -> start damage
var destroyed: Array[StringName] = []
var mission_zone_source: Area3D = null
var mission_zone_dest: Area3D = null
var deadline: float = 0.0
var time_limit_seconds: float = 0.0
var _started: bool = false
var _elapsed: float = 0.0
var _done_ids: Array[StringName] = []
var _opt_done_ids: Array[StringName] = []
var _poltergeist_timer: float = 4.0
var _spawned_debris: int = 0
var _tip_events: int = 0

signal objectives_tick

func _ready() -> void:
	EventBus.mission_started.connect(_on_started)
	EventBus.mission_accepted.connect(_on_accepted)
	EventBus.mission_cancelled.connect(_on_finished)
	EventBus.damage_changed.connect(_on_damage)
	EventBus.item_destroyed.connect(_on_destroyed)
	EventBus.player_exited_vehicle.connect(_on_vehicle_moved)

func _on_accepted(m: MissionData) -> void:
	_prepare(m)

func _on_started(m: MissionData) -> void:
	_prepare(m)
	_started = true

func _on_finished(_m: MissionData) -> void:
	_cleanup()

func _prepare(m: MissionData) -> void:
	if world == null:
		world = get_parent()
	tracking_items.clear()
	destroyed.clear()
	_elapsed = 0.0
	_done_ids.clear()
	_opt_done_ids.clear()
	_started = false
	time_limit_seconds = m.time_limit_seconds
	# Quellen-/Zielzonen bauen
	mission_zone_source = _make_zone(&"source", Vector3(-14, 0.05, 0), Vector3(9, 3, 12))
	mission_zone_dest = _make_zone(&"dest", Vector3(16, 0.05, 4), Vector3(6, 3, 8))
	# Möbel im Quellraum bereitstellen (Slice: direkt in der Halle)
	world.call("spawn_mission_manifest", m, mission_zone_source.global_position + Vector3(0, 1.2, 0))
	# Special rules
	if m.special_rules.has("haunted"):
		_poltergeist_timer = 3.0
	if m.special_rules.has("messy_hoard") and world.has_method("spawn_debris_pile"):
		_spawned_debris = world.call("spawn_debris_pile", 26, mission_zone_source.global_position)
	Missions.begin_in_progress()
	_started = true
	UI.mission_started_update()

func _make_zone(kind: StringName, center: Vector3, size: Vector3) -> Area3D:
	var zone := Area3D.new()
	zone.name = "MissionZone_%s" % String(kind)
	zone.collision_layer = 128   # Trigger
	zone.collision_mask = 0b111
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	zone.add_child(cs)
	zone.global_position = center
	zone.set_meta("zone_kind", kind)
	world.add_child(zone)
	return zone

func _physics_process(delta: float) -> void:
	if not _started or not Missions.has_active_mission():
		return
	var m: MissionData = Missions.active_mission
	_elapsed += delta
	_tick_special_rules(m, delta)
	var any_changed := false
	for o in m.objectives:
		if o.id in _done_ids or (o.optional and o.id in _opt_done_ids):
			continue
		if _evaluate(o, m):
			if o.optional:
				_opt_done_ids.append(o.id)
			else:
				_done_ids.append(o.id)
			EventBus.objective_completed.emit(m, o.id)
			UI.toast("Ziel erledigt: %s" % o.description)
			any_changed = true
		EventBus.objective_updated.emit(m, o.id, _progress(o, m))
	if any_changed:
		objectives_tick.emit()
	# Zeitlimit-Objective + globale Deadline
	if _elapsed > time_limit_seconds:
		var has_time_obj := false
		for o in m.objectives:
			if o.type == &"time_limit":
				has_time_obj = true
		if not has_time_obj:
			_finish(true, &"time")
		else:
			for o in m.objectives:
				if o.type == &"time_limit" and not (o.id in _done_ids):
					_finish(true, &"time")

func _evaluate(o: ObjectiveData, m: MissionData) -> bool:
	match o.type:
		&"time_limit":
			return _elapsed <= float(o.params.get("seconds", time_limit_seconds))
		&"no_damage_on":
			var fid := String(StringName(o.params.get("furniture_id", "")))
			var dmg := tracking_items.get(fid, 0.0)
			return dmg <= float(o.params.get("max_damage", 5.0))
		&"load_vehicle":
			return _loaded_count(m) >= maxi(o.required_count, 1) and _straps_ok(o, m)
		&"move_items":
			return _items_in_zone(mission_zone_dest) >= maxi(o.required_count, 1)
		&"deliver":
			return _deliver_ready(m)
		&"no_tip":
			return _tip_events == 0
		_:
			return false

func _progress(o: ObjectiveData, m: MissionData) -> float:
	match o.type:
		&"load_vehicle":
			return clampf(float(_loaded_count(m)) / float(maxi(o.required_count, 1)), 0.0, 1.0)
		&"move_items":
			return clampf(float(_items_in_zone(mission_zone_dest)) / float(maxi(o.required_count, 1)), 0.0, 1.0)
		&"no_damage_on":
			var fid := String(StringName(o.params.get("furniture_id", "")))
			var dmg := tracking_items.get(fid, 0.0)
			return clampf(1.0 - dmg / maxf(float(o.params.get("max_damage", 5.0)), 0.01), 0.0, 1.0)
	return 0.0

func _loaded_count(m: MissionData) -> int:
	var v := world.find_vehicle()
	if v == null:
		return 0
	var n := 0
	for f in m.furniture_manifest:
		if v.has_item(f.id) and v.cargo_items.size() > 0:
			n += 1
	return n

func _straps_ok(o: ObjectiveData, _m: MissionData) -> bool:
	var need := int(o.params.get("need_straps", 0))
	if need <= 0:
		return true
	var v := world.find_vehicle()
	if v == null:
		return false
	# CargoArea prüft Meta "straps" je Möbel (0..2) – Boni, kein harter Blocker.
	var cargo := v.get_node_or_null("CargoArea") as CargoArea
	if cargo == null:
		return true
	for it in v.cargo_items:
		if cargo.strap_level(it) >= need:
			return true
	return false

func _items_in_zone(zone: Area3D) -> int:
	if zone == null:
		return 0
	var n := 0
	for body in zone.get_overlapping_bodies():
		if body is FurnitureBody:
			var fb := body as FurnitureBody
			if fb.data != null and Missions.active_mission != null:
				for f in Missions.active_mission.furniture_manifest:
					if fb.data.id == f.id:
						n += 1
						break
	return n

func _deliver_ready(m: MissionData) -> bool:
	return _items_in_zone(mission_zone_dest) >= m.furniture_manifest.size() and _items_in_zone(mission_zone_dest) > 0

# ------------------------------------------------------------- special rules --

func _tick_special_rules(m: MissionData, delta: float) -> void:
	if m.special_rules.has("haunted"):
		_poltergeist_timer -= delta
		if _poltergeist_timer <= 0.0:
			_poltergeist_timer = randf_range(3.5, 9.0)
			_poltergeist_once(m)
	if m.special_rules.has("high_wind"):
		_wind_assault(delta)

func _poltergeist_once(m: MissionData) -> void:
	# Ein zufälliges Möbel bekommt einen Impuls + Licht-Flackern + Sound.
	var bodies := get_tree().get_nodes_in_group("furniture")
	var pool: Array = []
	for b in bodies:
		var fb := b as FurnitureBody
		if fb == null or fb.is_held() or fb.locked_in_cargo:
			continue
		pool.append(fb)
	if pool.is_empty():
		return
	var victim: FurnitureBody = pool[randi() % pool.size()]
	var dir := Vector3(randf_range(-1, 1), randf_range(0.1, 0.8), randf_range(-1, 1))
	victim.apply_impulse(dir * victim.mass * 1.4)
	Sfx.play_world(victim.global_position, &"ghost_whoosh", -8.0)
	var env := get_tree().get_first_node_in_group("world")
	if env != null and env.has_method("flicker_lights"):
		env.call("flicker_lights", 0.8)
	UI.toast("…das Regal hat sich gerade bewegt.")

func _wind_assault(_delta: float) -> void:
	# Auf Halde-Objekte (in hold, aber nicht im Truck) wirken Windböen (#46).
	var gust := WeatherAccess.gust(18.0)
	if gust.length_squared() < 0.01:
		return
	for b in get_tree().get_nodes_in_group("furniture"):
		var fb := b as FurnitureBody
		if fb == null or not fb.is_held():
			continue
		if fb.mass < 90.0:
			fb.apply_central_impulse(gust * fb.mass * 0.06)

# ---------------------------------------------------------------- tracking --

func _on_damage(body: RigidBody3D, percent: float, _cause: StringName) -> void:
	if not _started or Missions.active_mission == null:
		return
	if not (body is FurnitureBody):
		return
	var fb := body as FurnitureBody
	if fb.data == null:
		return
	for f in Missions.active_mission.furniture_manifest:
		if fb.data.id == f.id:
			tracking_items[String(f.id)] = maxf(tracking_items.get(String(f.id), 0.0), percent)
			break

func _on_destroyed(body: RigidBody3D) -> void:
	if not _started or Missions.active_mission == null:
		return
	var fb := body as FurnitureBody
	if fb == null or fb.data == null:
		return
	for f in Missions.active_mission.furniture_manifest:
		if fb.data.id == f.id and not (f.id in destroyed):
			destroyed.append(f.id)

func _on_vehicle_moved(_v: VehicleController, _p: Node) -> void:
	pass

# ----------------------------------------------------------------- finish --

func _finish(fail: bool, reason: StringName) -> void:
	if not _started or Missions.active_mission == null:
		return
	_started = false
	var m: MissionData = Missions.active_mission
	if fail:
		Missions.report_outcome({"payout": PayoutCalculator.failed_result(m, reason), "grade": &"failed"})
	else:
		var payout := PayoutCalculator.calculate(m, tracking_items, _elapsed, _done_ids, _opt_done_ids, destroyed)
		Missions.report_outcome({"payout": payout, "grade": payout.grade})
	_cleanup()

func force_finish() -> void:
	_finish(false, &"debug")

func _cleanup() -> void:
	for z in [mission_zone_source, mission_zone_dest]:
		if z != null and is_instance_valid(z):
			z.queue_free()
	mission_zone_source = null
	mission_zone_dest = null

func debug_state() -> String:
	return "elapsed %.0f / %.0f s, done %d, destroyed %d" % [_elapsed, time_limit_seconds, _done_ids.size(), destroyed.size()]
