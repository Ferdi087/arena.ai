extends Node
## Company Service (Autoload "Company") – Geld, Reputation, Level, Unlock,
## Marketing, Mitarbeiter, Fuhrpark. Alle Regeln laufen hier; UI liest nur mit.
## Autoload-Begründung: Fortschritt ist szenenübergreifend (HQ <-> Stadt <->
## Shop) und Save-Anker. Netzwerk: Änderungen NUR auf dem Autority-Host,
## Clients kriechen über rpc-broadcast (s. apply_*_rpc) – Money-Checks sind clientseitig
## ohnehin nur Anzeige.

var data: CompanyData = CompanyData.new()
var employees: Array[EmployeeData] = []
var owned_vehicle_upgrades: Dictionary[StringName, PackedStringArray] = {} # vehicle_id -> upgrades

var save_key: String = "company"

@onready var _econ: EconomySettings = Content.economy_settings

signal employees_changed
signal vehicle_purchased(vehicle_id: StringName)

func _ready() -> void:
	if data.money == 0.0:
		data.money = 1500.0

# ------------------------------------------------------------------- Setup --

func begin_new_company(company_name: String) -> void:
	data = CompanyData.new()
	data.company_name = company_name if not company_name.strip_edges().is_empty() else "Möbel-Rambo GmbH"
	data.money = 1500.0
	data.reputation = 10.0
	data.company_level = 1
	data.owned_vehicles = PackedStringArray(["starter_truck"])
	employees.clear()
	owned_vehicle_upgrades.clear()
	Saves.mark_dirty()

# ---------------------------------------------------------------- Economy --

var money: float:
	get:
		return data.money

var reputation: float:
	get:
		return data.reputation

var company_level: int:
	get:
		return data.company_level

var xp: float:
	get:
		return data.xp

func add_money(amount: float, reason: String = "") -> void:
	data.money = maxf(0.0, data.money + amount)
	if amount > 0.0:
		data.stats["money_earned"] = float(data.stats.get("money_earned", 0.0)) + amount
	EventBus.money_changed.emit(data.money, amount)
	Saves.mark_dirty()
	if reason != "" and Dev.debug_enabled_in_hud():
		push_warning("Company: money +%.0f (%s)" % [amount, reason])

func try_spend(amount: float, reason: String = "") -> bool:
	if data.money < amount:
		if Net.is_authority_player():
			UI.toast("Nicht genug Geld: %.0f € nötig (%s)" % [amount, reason])
		return false
	data.money -= amount
	EventBus.money_changed.emit(data.money, -amount)
	Saves.mark_dirty()
	return true

func add_reputation(delta_rep: float) -> void:
	var before := data.reputation
	data.reputation = clampf(data.reputation + delta_rep, _econ.rep_min, _econ.rep_max)
	EventBus.reputation_changed.emit(data.reputation, data.reputation - before)
	Saves.mark_dirty()

func add_xp(amount: float) -> void:
	data.xp += amount
	var needed := level_xp_needed(data.company_level)
	while data.xp >= needed:
		data.xp -= needed
		data.company_level += 1
		needed = level_xp_needed(data.company_level)
		UI.banner("FIRMA LEVEL %d" % data.company_level)
		EventBus.unlock_changed.emit(&"company_level", true)
	Saves.mark_dirty()

func level_xp_needed(level: int) -> float:
	return _econ.level_base_xp * pow(_econ.level_xp_growth, float(maxi(level - 1, 0)))

# ----------------------------------------------------------------- Unlocks --

func has_unlock(flag: StringName) -> bool:
	return flag != &"" and data.unlocked_flags.has(String(flag))

func unlock(flag: StringName) -> void:
	if data.unlocked_flags.has(String(flag)):
		return
	data.unlocked_flags.append(String(flag))
	EventBus.unlock_changed.emit(flag, true)
	Saves.mark_dirty()

func has_purchased(cosmetic_id: StringName) -> bool:
	return data.purchased_cosmetics.has(String(cosmetic_id))

func purchase_cosmetic(cosmetic: CosmeticData) -> bool:
	if has_purchased(cosmetic.id):
		return true
	if not try_spend(cosmetic.price, "Kleidung"):
		return false
	data.purchased_cosmetics.append(String(cosmetic.id))
	Saves.mark_dirty()
	return true

func catalog_collect(furniture: FurnitureData) -> void:
	if furniture == null or data.collected_catalog.has(String(furniture.id)):
		return
	data.collected_catalog.append(String(furniture.id))
	Saves.mark_dirty()

# ---------------------------------------------------------------- Vehicles --

func owns_vehicle(vehicle_id: StringName) -> bool:
	return data.owned_vehicles.has(String(vehicle_id))

func buy_vehicle(v: VehicleData) -> bool:
	if owns_vehicle(v.id):
		return true
	if company_level < v.required_company_level:
		UI.toast("Zu niedriges Firmenlevel für %s" % v.display_name)
		return false
	if not try_spend(v.purchase_price, v.display_name):
		return false
	data.owned_vehicles.append(String(v.id))
	vehicle_purchased.emit(v.id)
	Saves.mark_dirty()
	return true

func can_afford_upgrade(u: UpgradeData) -> bool:
	return data.money >= u.cost and company_level >= u.required_company_level and reputation >= u.required_reputation

func buy_upgrade(vehicle_id: StringName, u: UpgradeData) -> bool:
	if not can_afford_upgrade(u):
		UI.toast("Upgrade nicht verfügbar/finanzierbar")
		return false
	if not try_spend(u.cost, u.display_name):
		return false
	if not owned_vehicle_upgrades.has(vehicle_id):
		owned_vehicle_upgrades[vehicle_id] = PackedStringArray()
	if not owned_vehicle_upgrades[vehicle_id].has(String(u.id)):
		owned_vehicle_upgrades[vehicle_id].append(String(u.id))
	Saves.mark_dirty()
	return true

func upgrades_for(vehicle_id: StringName) -> PackedStringArray:
	return owned_vehicle_upgrades.get(vehicle_id, PackedStringArray())

func effective_vehicle_data(vehicle_id: StringName) -> VehicleData:
	## VehicleData + gekaufte Upgrades (Multiplikativ/Additiv/Set), ohne die
	## Katalog-Ressource zu mutieren -> deterministisch & netzwerktauglich.
	var base: VehicleData = Content.get_vehicle(vehicle_id)
	if base == null:
		push_error("Company: VehicleData fehlt: %s" % vehicle_id)
		return null
	var v: VehicleData = base.duplicate(true)
	for uid in upgrades_for(vehicle_id):
		var u: UpgradeData = Content.get_upgrade(StringName(uid))
		if u == null:
			continue
		for prop in u.modifiers:
			var spec: Dictionary = u.modifiers[prop]
			var cur: Variant = v.get(prop)
			if cur == null:
				continue
			if spec.has("mult"):
				v.set(prop, cur * float(spec["mult"]))
			elif spec.has("add"):
				v.set(prop, cur + float(spec["add"]))
			elif spec.has("set"):
				v.set(prop, spec["set"])
			elif spec.has("vector_add"):
				var va: Array = spec["vector_add"]
				v.set(prop, Vector3(cur.x + float(va[0]), cur.y + float(va[1]), cur.z + float(va[2])))
	return v

# ---------------------------------------------------------------- Marketing --

func set_marketing_tier(tier: int) -> void:
	var t := clampi(tier, 0, _econ.marketing_costs.size() - 1)
	if t == data.marketing_tier:
		return
	var cost: float = _econ.marketing_costs[t] - _econ.marketing_costs[data.marketing_tier]
	if cost > 0.0 and not try_spend(cost, "Marketing"):
		return
	data.marketing_tier = t
	EventBus.marketing_changed.emit(t)
	Saves.mark_dirty()

func marketing_demand_factor() -> float:
	return _econ.marketing_demand_factor[clampi(data.marketing_tier, 0, _econ.marketing_demand_factor.size() - 1)]

func marketing_quality_factor() -> float:
	return _econ.marketing_quality_factor[clampi(data.marketing_tier, 0, _econ.marketing_quality_factor.size() - 1)]

# ---------------------------------------------------------------- Employees --

func hire(employee: EmployeeData) -> bool:
	if not try_spend(employee.wage_per_hour * 8.0, "Einstellung"):
		return false
	employees.append(employee)
	employees_changed.emit()
	Saves.mark_dirty()
	return true

func fire(index: int) -> void:
	if index >= 0 and index < employees.size():
		employees.remove_at(index)
		employees_changed.emit()
		Saves.mark_dirty()

func total_wage_per_job() -> float:
	var sum := 0.0
	for e in employees:
		sum += e.wage_per_hour * _econ.employee_upkeep_multiplier
	return sum

# ----------------------------------------------------------------- Website --

func set_website(name_s: String, theme: StringName, color: Color, slogan: String, about: String) -> void:
	if not name_s.strip_edges().is_empty():
		data.company_name = name_s
	data.website_theme = theme
	data.brand_color = color
	data.slogan = slogan
	data.website_about_text = about
	# Website-Effekt auf Kundenqualität (Reputation-Basis) – #18:
	match String(theme):
		"budget": add_reputation(0.5)
		"clean": add_reputation(1.5)
		"flashy": add_reputation(2.5)
		"luxury": add_reputation(4.0)
	Saves.mark_dirty()

func logo_image(size: int = 128) -> ImageTexture:
	## Deterministisches Procedural-Logo (Firmenfarben + Seed) – echtes Rendering,
	## kein Platzhalter: SVG-artige Balken + Initialen-Boxen.
	var img := Image.create(size, size, false, Image.Format.FORMAT_RGBA8)
	var bg := data.brand_color
	img.fill(Color(0.07, 0.08, 0.11, 1.0))
	var rnd := RandomNumberGenerator.new()
	rnd.seed = data.logo_seed
	for i in 5:
		var h := int(lerpf(float(size) * 0.18, float(size) * 0.55, rnd.randf()))
		var w := int(float(size) * 0.12)
		var x0 := int(float(size) * (0.1 + float(i) * 0.16))
		var y0 := size - h - int(float(size) * 0.12)
		var col := bg.lightened(0.1 * float(i))
		for yy in range(y0, min(size, size - int(float(size) * 0.12))):
			for xx in range(x0, min(size, x0 + w)):
				img.set_pixel(xx, yy, col)
	# Outline
	for x in size:
		img.set_pixel(x, 0, Color(0.95, 0.62, 0.12))
		img.set_pixel(x, size - 1, Color(0.95, 0.62, 0.12))
	for y in size:
		img.set_pixel(0, y, Color(0.95, 0.62, 0.12))
		img.set_pixel(size - 1, y, Color(0.95, 0.62, 0.12))
	return ImageTexture.create_from_image(img)

# -------------------------------------------------------------------- Save --

func save_to_dict() -> Dictionary:
	return {
		"company": {
			"name": data.company_name, "slogan": data.slogan, "logo_seed": data.logo_seed,
			"brand": data.brand_color.to_html(), "website_theme": String(data.website_theme),
			"about": data.website_about_text,
			"money": data.money, "reputation": data.reputation, "level": data.company_level,
			"xp": data.xp, "marketing": data.marketing_tier,
			"unlocked": data.unlocked_flags, "purchased": data.purchased_cosmetics,
			"catalog": data.collected_catalog, "vehicles": data.owned_vehicles,
			"stats": data.stats,
		},
		"employees": employees.map(func(e: EmployeeData) -> Dictionary: return {
			"id": String(e.id), "first_name": e.first_name, "traits": e.traits,
			"speed": e.speed, "strength": e.strength, "accuracy": e.accuracy,
			"intelligence": e.intelligence, "reliability": e.reliability,
			"stress_resistance": e.stress_resistance, "driving_skill": e.driving_skill,
			"furniture_knowledge": e.furniture_knowledge, "wage": e.wage_per_hour,
			"specialty": String(e.specialty), "xp": e.xp,
		}),
		"upgrades": _serialize_upgrades(),
	}

func _serialize_upgrades() -> Dictionary:
	var out := {}
	for vid in owned_vehicle_upgrades:
		out[String(vid)] = Array(owned_vehicle_upgrades[vid])
	return out

func load_from_dict(d: Dictionary) -> void:
	var csec: Dictionary = d.get("company", {})
	data = CompanyData.new()
	data.company_name = String(csec.get("name", data.company_name))
	data.slogan = String(csec.get("slogan", ""))
	data.logo_seed = int(csec.get("logo_seed", 1337))
	data.brand_color = Color(String(csec.get("brand", "f29d1fff")))
	data.website_theme = StringName(String(csec.get("website_theme", "budget")))
	data.website_about_text = String(csec.get("about", ""))
	data.money = float(csec.get("money", 1500.0))
	data.reputation = float(csec.get("reputation", 10.0))
	data.company_level = int(csec.get("level", 1))
	data.xp = float(csec.get("xp", 0.0))
	data.marketing_tier = int(csec.get("marketing", 0))
	data.unlocked_flags = PackedStringArray(csec.get("unlocked", []))
	data.purchased_cosmetics = PackedStringArray(csec.get("purchased", []))
	data.collected_catalog = PackedStringArray(csec.get("catalog", []))
	data.owned_vehicles = PackedStringArray(csec.get("vehicles", ["starter_truck"]))
	data.stats = csec.get("stats", {})
	employees.clear()
	for raw in d.get("employees", []):
		var e := EmployeeData.new()
		var rd: Dictionary = raw
		e.id = StringName(String(rd.get("id", "")))
		e.first_name = String(rd.get("first_name", "Bodo"))
		e.traits = String(rd.get("traits", ""))
		e.speed = float(rd.get("speed", 0.5)); e.strength = float(rd.get("strength", 0.5))
		e.accuracy = float(rd.get("accuracy", 0.5)); e.intelligence = float(rd.get("intelligence", 0.5))
		e.reliability = float(rd.get("reliability", 0.5)); e.stress_resistance = float(rd.get("stress_resistance", 0.5))
		e.driving_skill = float(rd.get("driving_skill", 0.5)); e.furniture_knowledge = float(rd.get("furniture_knowledge", 0.5))
		e.wage_per_hour = float(rd.get("wage", 12.0)); e.specialty = StringName(String(rd.get("specialty", "carry")))
		e.xp = float(rd.get("xp", 0.0))
		employees.append(e)
	var ups: Dictionary = d.get("upgrades", {})
	owned_vehicle_upgrades.clear()
	for vid in ups:
		owned_vehicle_upgrades[StringName(vid)] = PackedStringArray(ups[vid])
	# Signale für UI-Reaktion
	EventBus.money_changed.emit(data.money, 0.0)
	EventBus.reputation_changed.emit(data.reputation, 0.0)
	employees_changed.emit()
