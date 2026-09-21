extends Node
## Mission Service (Autoload "Missions") – Auftragsangebote verwalten, annehmen,
## aktiven Auftrag halten. Die LAUFZEIT-Auswertung (Objectives in der Welt) macht
## MissionRuntime in der Welt-Szene; hier leben nur Daten + Status-Mutators,
## damit Menu/HUD/Welt alle dieselbe Quelle lesen.
## Save-Contributor ("missions"). Network: accept/complete laufen über Net-RPCs.

enum MissionPhase { NONE, ACCEPTED, IN_PROGRESS, COMPLETED, FAILED, ABANDONED, PARTIAL }

var offered: Array[MissionData] = []
var active_mission: MissionData = null
var phase: int = MissionPhase.NONE
var accepted_time_msec: int = 0
var history: Array[Dictionary] = [] # {id, grade, payout, damaged, ts}

var save_key: String = "missions"

var _refresh_accum: float = 0.0

func _ready() -> void:
	_refresh_job_board(false)

func _process(delta: float) -> void:
	# Auftragsbrett-Leben: Reicht Marketing, wachsen neue Angebote.
	# Kein pro-Frame-Job: 1x pro 10s checken (#74).
	_refresh_accum += delta
	if _refresh_accum < 10.0:
		return
	_refresh_accum = 0.0
	_refresh_job_board(true)

func has_active_mission() -> bool:
	return active_mission != null

func available_jobs_count() -> int:
	return offered.size()

func accept(mission: MissionData) -> bool:
	if has_active_mission():
		UI.toast("Erst aktuellen Auftrag abschließen/abbrechen!")
		return false
	if mission.min_company_level > Company.company_level:
		return false
	if mission.min_reputation > Company.reputation:
		return false
	active_mission = mission
	phase = MissionPhase.ACCEPTED
	accepted_time_msec = Time.get_ticks_msec()
	offered.erase(mission)
	EventBus.mission_accepted.emit(mission)
	Saves.mark_dirty()
	UI.mission_started_update()
	return true

func abandon() -> void:
	if not has_active_mission():
		return
	var m := active_mission
	active_mission = null
	phase = MissionPhase.ABANDONED
	Company.add_reputation(-2.0)
	Company.add_money(-250.0, "Stornogebühr")
	EventBus.mission_cancelled.emit(m)
	history.append({"id": String(m.mission_id), "grade": "abandoned", "payout": -250.0, "ts": Time.get_unix_time_from_system()})
	Saves.mark_dirty()

func begin_in_progress() -> void:
	if has_active_mission() and phase == MissionPhase.ACCEPTED:
		phase = MissionPhase.IN_PROGRESS
		EventBus.mission_started.emit(active_mission)

func report_outcome(result: Dictionary) -> void:
	## Wird von MissionRuntime (Welt) aufgerufen – enthält payout + damage.
	if not has_active_mission():
		return
	var m := active_mission
	var payout: PayoutResult = result.get("payout", null)
	var grade: StringName = result.get("grade", &"ok")
	phase = MissionPhase.COMPLETED if grade != &"failed" else MissionPhase.FAILED
	if payout != null:
		Company.add_money(payout.final_amount, "Auftrag %s" % m.display_name)
		Company.add_reputation(payout.reputation_delta)
		Company.add_xp(_xp_for(m, grade))
		if grade == &"flawless":
			Company.unlock(&"flawless_1")
		history.append({
			"id": String(m.mission_id), "grade": String(grade),
			"payout": payout.final_amount, "ts": Time.get_unix_time_from_system(),
		})
		EventBus.mission_completed.emit(m, payout)
	else:
		Company.add_reputation(-Content.damage_settings.fail_reputation_loss)
		EventBus.mission_failed.emit(m, &"time")
		history.append({"id": String(m.mission_id), "grade": "failed", "payout": 0.0, "ts": Time.get_unix_time_from_system()})
	active_mission = null
	Saves.mark_dirty()
	UI.mission_finished_update()

func _xp_for(m: MissionData, grade: StringName) -> float:
	var mult := 1.0
	match String(grade):
		"flawless": mult = 1.4
		"good": mult = 1.15
		"ok": mult = 1.0
		"poor": mult = 0.7
		"failed": mult = 0.25
	match int(m.difficulty):
		0: mult *= 0.8
		1: mult *= 1.0
		2: mult *= 1.35
		3: mult *= 1.8
	return Content.economy_settings.xp_per_job_normal * mult

func debug_force_complete() -> void:
	if has_active_mission():
		var payout := PayoutResult.new()
		payout.base_payment = active_mission.base_payment
		payout.final_amount = active_mission.base_payment
		payout.grade = &"flawless"
		payout.breakdown_lines = PackedStringArray(["DEBUG-PAYOUT"])
		report_outcome({"payout": payout, "grade": &"flawless"})

# ------------------------------------------------------------------ Board --

func _refresh_job_board(only_grow: bool) -> void:
	var target := int(clampf(2.0 + 2.0 * Company.marketing_demand_factor(), 2, 7))
	if not only_grow:
		offered.clear()
	while offered.size() < target:
		var gen := _generate_mission()
		if gen == null:
			break
		offered.append(gen)
	# Alte, unbezahlte Angebote verwelchen nach einer Weile (Marketing-Druck #19)

func _generate_mission() -> MissionData:
	var pool := Content.mission_pool(Company.company_level, maxf(0.0, Company.reputation - 15.0))
	if pool.is_empty():
		# Fallback:baue mini Parametric-Mission aus Datenbestand
		return _procedural_mission()
	var base: MissionData = pool[randi() % pool.size()]
	var m: MissionData = base.duplicate(true)
	m.mission_id = StringName(Content.make_mission_id())
	m.display_name = "%s – Job %s" % [base.display_name, String(m.mission_id).to_upper()]
	# Parameter-Jitter (prozedural, #42): Bezahlung an Rep/Marketing koppeln
	var quality: float = 0.8 + 0.4 * randf()
	quality *= 0.85 + 0.3 * Company.marketing_quality_factor()
	quality *= 1.0 + 0.12 * Company.reputation / 25.0
	m.base_payment = snapf(m.base_payment * quality, 5.0)
	m.time_limit_seconds = clampf(m.time_limit_seconds * (0.9 + 0.25 * randf()), 180.0, 3600.0)
	# Manifest auf max. 6 Items stutzen/vervollständigen
	if m.furniture_manifest.size() > 6:
		var cut: Array[FurnitureData] = []
		for i in 6:
			cut.append(m.furniture_manifest[i])
		m.furniture_manifest = cut
	return m

func _procedural_mission() -> MissionData:
	var m := MissionData.new()
	m.mission_id = StringName(Content.make_mission_id())
	var all := Content.all_furniture()
	if all.is_empty():
		return null
	var count := randi_range(2, 4)
	var items: Array[FurnitureData] = []
	for i in count:
		items.append(all[randi() % all.size()])
	m.furniture_manifest = items
	var total_value := 0.0
	var max_haul := 1
	for f in items:
		total_value += f.item_value
		max_haul = maxi(max_haul, f.required_haulers)
	m.base_payment = snapf(150.0 + total_value * 0.9 + float(max_haul) * 120.0, 5.0)
	m.time_limit_seconds = 300.0 + 90.0 * float(count)
	m.display_name = "Spontanauftrag %s" % String(m.mission_id).to_upper()
	m.description = "Kunde angerufen über die Firma-Website."
	m.difficulty = MissionData.Difficulty.EASY if count <= 2 else MissionData.Difficulty.NORMAL
	return m

func elapsed_seconds() -> float:
	return float(Time.get_ticks_msec() - accepted_time_msec) / 1000.0

# ------------------------------------------------------------------- Save --

func save_to_dict() -> Dictionary:
	return {
		"active_id": String(active_mission.mission_id) if active_mission != null else "",
		"active_snapshot": _pack_mission(active_mission) if active_mission != null else {},
		"phase": phase,
		"history": history.slice(0, 40),
		"offered_ids": offered.map(func(m: MissionData) -> String: return String(m.mission_id)),
	}

func load_from_dict(d: Dictionary) -> void:
	history.clear()
	for raw in d.get("history", []):
		history.append(raw)
	active_mission = null
	var snap: Dictionary = d.get("active_snapshot", {})
	if not snap.is_empty():
		active_mission = _unpack_mission(snap)
	phase = int(d.get("phase", MissionPhase.NONE))
	if active_mission != null and phase == int(MissionPhase.NONE):
		phase = MissionPhase.ACCEPTED
	# Angebotene Jobs: generisch neu würfeln (Angebot = flüchtig, Fortschritt = fest)
	offered.clear()
	_refresh_job_board(false)

func _pack_mission(m: MissionData) -> Dictionary:
	return {
		"id": String(m.mission_id), "name": m.display_name, "client": m.client_name,
		"pay": m.base_payment, "time": m.time_limit_seconds,
		"items": m.furniture_manifest.map(func(f: FurnitureData) -> String: return String(f.id)),
		"rules": Array(m.special_rules),
	}

func _unpack_mission(d: Dictionary) -> MissionData:
	var m := MissionData.new()
	m.mission_id = StringName(String(d.get("id", "job_loaded")))
	m.display_name = String(d.get("name", "Auftrag"))
	m.client_name = String(d.get("client", "Kunde"))
	m.base_payment = float(d.get("pay", 500.0))
	m.time_limit_seconds = float(d.get("time", 600.0))
	var items: Array[FurnitureData] = []
	for fid in d.get("items", []):
		var f: FurnitureData = Content.get_furniture(StringName(String(fid)))
		if f != null:
			items.append(f)
		else:
			push_warning("Missions: Möbel '%s' im Save nicht mehr im Katalog – Fallback Karton." % fid)
			var fb: FurnitureData = Content.get_furniture(&"cardboard_small")
			if fb != null:
				items.append(fb)
	m.furniture_manifest = items
	var rules: PackedStringArray = PackedStringArray(d.get("rules", []))
	m.special_rules = rules
	return m
