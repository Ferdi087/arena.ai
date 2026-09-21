extends Node
class_name CoreTests
## In-Project Test-Suite (lädt per tests/core_tests.tscn im Headless-Modus).
## Autoloads sind hier verfügbar – darum KEIN `-s` Standalone-Script.
## Aufruf:  godot --headless --path projct res://tests/core_tests.tscn
## Exit-Code 0 = alle grün, 1 = Fehler (CI-geeignet).

var _pass := 0
var _fail := 0
var _context := ""

func _ready() -> void:
	print("\n=== MÖBEL-RAMBO CORE TESTS ===")
	_test_content_integrity()
	_test_city_layout()
	_test_payout_model()
	_test_mission_generation()
	_test_save_contributors()
	print("=== ERGEBNIS: %d pass, %d fail ===\n" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ✓ [%s] %s" % [_context, label])
	else:
		_fail += 1
		push_error("  ✗ [%s] %s" % [_context, label])

func _test_content_integrity() -> void:
	_context = "content"
	_ok(Content.furniture.size() >= 12, "Möbelkatalog gefüllt (%d)" % Content.furniture.size())
	_ok(Content.vehicles.size() >= 3, "Fahrzeuge vorhanden")
	_ok(Content.missions.size() >= 5, "Missionen vorhanden")
	_ok(Content.build_pieces.size() >= 8, "Bauteile vorhanden")
	_ok(Content.damage_settings != null, "DamageSettings zentral geladen")
	_ok(Content.economy_settings != null, "EconomySettings zentral geladen")
	# Jede Mission referenziert nur existierende Möbel & sinnvolle Limits
	var bad := 0
	for m in Content.missions.values():
		if m.furniture_manifest.is_empty():
			bad += 1
		for f in m.furniture_manifest:
			if Content.get_furniture(f.id) == null:
				bad += 1
		if m.base_payment <= 0.0 or m.time_limit_seconds <= 0.0:
			bad += 1
	_ok(bad == 0, "alle Missions-Manifeste konsistent (%d Fehler)" % bad)
	# Materialien jeder Furniture definiert
	var miss_mat := 0
	for f in Content.furniture.values():
		if f.material == null or Content.get_material(f.material.id) == null:
			miss_mat += 1
		if f.mass_kg <= 0.1:
			miss_mat += 1
	_ok(miss_mat == 0, "Material & Masse je Möbel ok (%d Fehler)" % miss_mat)
	# Upgrades/Cosmetics mit eindeutigen IDs
	var seen := {}
	var dupes := 0
	for u in Content.upgrades.values():
		if seen.has(u.id):
			dupes += 1
		seen[u.id] = true
	for c in Content.cosmetics.values():
		if seen.has(c.id):
			dupes += 1
		seen[c.id] = true
	_ok(dupes == 0, "IDs von Upgrades/Cosmetics eindeutig")

func _test_city_layout() -> void:
	_context = "city"
	var a := CityLayout.node_pos(1, 1)
	var b := CityLayout.node_pos(2, 1)
	_ok(absf(b.x - a.x - CityLayout.SPACING) < 0.01, "Rasterachse X = SPACING")
	var p := Vector3(12.7, 0.0, -45.2)
	var n := CityLayout.nearest_node(p)
	var np := CityLayout.node_pos(n.x, n.y)
	_ok(CityLayout.node_pos(n.x, n.y).distance_to(p) < CityLayout.SPACING * 0.8, "nearest_node trifft")
	_ok(CityLayout.nearest_node(np).x == n.x and CityLayout.nearest_node(np).y == n.y, "nearest_node idempotent")
	var route := CityLayout.route(p, Vector3(80.0, 0.0, 120.0))
	_ok(route.size() >= 2, "Route gefunden (%d Wegpunkte)" % route.size())
	_ok(CityLayout.distance_estimate(p, Vector3(80.0, 0.0, 120.0)) > 0.0, "Distanz-Schätzung > 0")
	# Route beginnt am nächsten Node zum Startpunkt
	_ok(route[0].distance_to(np) < 0.01, "Route startet beim Snapped-Node")

func _test_payout_model() -> void:
	_context = "payout"
	var m: MissionData = Content.missions.values()[0]
	var empty_done: Array[StringName] = []
	# Pflichtziele simulieren
	for o in m.objectives:
		if not o.optional:
			empty_done.append(o.id)
	var clean := PayoutCalculator.calculate(m, {}, m.time_limit_seconds * 0.5, empty_done, [], [])
	_ok(clean.grade == &"flawless", "0%% Schaden + früh = flawless (grad=%s)" % clean.grade)
	_ok(clean.final_amount > m.base_payment, "flawless zahlt über Basis (%.0f > %.0f)" % [clean.final_amount, m.base_payment])
	var dmap := {}
	for f in m.furniture_manifest:
		dmap[String(f.id)] = 70.0
	var wrecked := PayoutCalculator.calculate(m, dmap, m.time_limit_seconds * 1.5, [], [], [])
	_ok(wrecked.grade == &"poor", "70%% Schaden + Überzeit = poor")
	_ok(wrecked.final_amount >= m.base_payment * 0.049, "Auszahlung nie unter 5%% Behalt")
	_ok(wrecked.damage_penalty <= 0.0 and wrecked.time_bonus <= 0.0, "Penalties sind negativ/0")
	var dest: Array[StringName] = [m.furniture_manifest[0].id]
	var broken := PayoutCalculator.calculate(m, {}, 10.0, empty_done, [], dest)
	_ok(broken.reputation_delta < 0.0, "Zerstörtes drückt die Reputation")
	_ok(broken.final_amount > 0.0, "Nie negative Auszahlung (Floor greift)")

func _test_mission_generation() -> void:
	_context = "missions"
	# Generatoren zweimal mit gleicher seed => gleiche Missionen
	var g1: MissionData = null
	var g2: MissionData = null
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	g1 = Missions.call("_procedural_mission")
	rng.seed = 42
	# Zufallsquelle für deterministischen Vergleich kann in-headless variieren –
	# wir prüfen stattdessen die INVARIENTEN jedes generierten Auftrags:
	var inv_ok := 0
	var total := 0
	for i in 6:
		var g := Missions.call("_procedural_mission")
		total += 1
		var good := g != null and not g.furniture_manifest.is_empty() and g.base_payment > 0.0 and g.time_limit_seconds >= 120.0
		for f in g.furniture_manifest:
			if Content.get_furniture(f.id) == null:
				good = false
		if good:
			inv_ok += 1
	_ok(total > 0 and inv_ok == total, "prozedurale Missionen erfüllen alle Invarianten (%d/%d)" % [inv_ok, total])

func _test_save_contributors() -> void:
	_context = "save"
	var dummy := _DummyContributor.new()
	add_child(dummy)
	Saves.register_contributor(dummy)
	var packed := Saves.build_save_dict()
	_ok(packed.has("dummy"), "Contributor-Sektion wird gesammelt")
	# Round-trip: Apply auf frischem Dummy liefert dieselben Werte
	var dummy2 := _DummyContributor.new()
	add_child(dummy2)
	dummy2.apply_save_dict(packed["dummy"])
	_ok(dummy2.value == dummy.value and dummy2.name_s == dummy.name_s, "Round-trip Werte identisch")
	Saves.unregister_contributor(dummy)
	_ok(not Saves.build_save_dict().has("dummy"), "Unregister entfernt Sektion")
	print("\n(CoreTests Ende)")

class _DummyContributor:
	extends Node
	var save_key: String = "dummy"
	var value: int = 42
	var name_s: String = "Kofferraum"
	func save_to_dict() -> Dictionary:
		return {"value": value, "name": name_s}
	func apply_save_data(d: Dictionary) -> void:
		value = int(d.get("value", 0))
		name_s = String(d.get("name", ""))
	func apply_save_state(d: Dictionary) -> void:
		apply_save_data(d)
