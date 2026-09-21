extends Node
## Content Database (Autoload "Content") – DER data-driven Einstiegspunkt.
##
## Aufbau (#37/#89/#123/#136):
##  1. Grundkatalog wird hier deterministisch im Code gebaut (out-of-the-box spielbar).
##  2. Zusätzlich werden ALLE *.tres in res://data/definitions/{furniture,missions,
##     vehicles,cosmetics,build,upgrades} eingelesen und überschreiben/ergänzen
##     per id. => Ein neues Möbel = Model + .tres, KEIN Core-Code-Wechsel.
##  3. Systeme fragen nur Content.get_* ab, kennen keine Pfade.

var furniture: Dictionary[StringName, FurnitureData] = {}
var vehicles: Dictionary[StringName, VehicleData] = {}
var missions: Dictionary[StringName, MissionData] = {}
var cosmetics: Dictionary[StringName, CosmeticData] = {}
var build_pieces: Dictionary[StringName, BuildPieceData] = {}
var upgrades: Dictionary[StringName, UpgradeData] = {}
var materials: Dictionary[StringName, MaterialDef] = {}
var damage_settings: DamageSettings = null
var economy_settings: EconomySettings = null

func _ready() -> void:
	_build_materials()
	_build_damage_and_economy()
	_build_furniture()
	_build_vehicles()
	_build_cosmetics()
	_build_pieces()
	_build_upgrades()
	_overlay_from_definitions()

# ---------------------------------------------------------------- getters --

func get_furniture(id: StringName) -> FurnitureData:
	return furniture.get(id)

func get_vehicle(id: StringName) -> VehicleData:
	return vehicles.get(id)

func get_mission(id: StringName) -> MissionData:
	return missions.get(id)

func get_cosmetic(id: StringName) -> CosmeticData:
	return cosmetics.get(id)

func get_build_piece(id: StringName) -> BuildPieceData:
	return build_pieces.get(id)

func get_upgrade(id: StringName) -> UpgradeData:
	return upgrades.get(id)

func get_material(id: StringName) -> MaterialDef:
	return materials.get(id)

func all_furniture() -> Array[FurnitureData]:
	var out: Array[FurnitureData] = []
	for k in furniture:
		out.append(furniture[k])
	return out

func mission_pool(min_level: int, min_rep: float) -> Array[MissionData]:
	var out: Array[MissionData] = []
	for m in missions.values():
		if m.min_company_level <= min_level and m.min_reputation <= min_rep:
			out.append(m)
	return out

# ------------------------------------------------------------ materials --

func _mat(id: StringName, name_s: String, t: int, fr: float, wet: float, dmg: float, snd: StringName, fracture: StringName, dens: float = 0.8) -> void:
	var m := MaterialDef.new()
	m.id = id; m.display_name = name_s; m.material_type = t as MaterialDef.MaterialType
	m.friction_dry = fr; m.friction_wet_multiplier = wet
	m.damage_multiplier = dmg; m.impact_sound_set = snd; m.fracture_behavior = fracture
	m.density = dens
	materials[id] = m

func _build_materials() -> void:
	_mat(&"wood", "Holz", MaterialDef.MaterialType.WOOD, 0.85, 0.55, 1.0, &"wood", &"scratch", 0.7)
	_mat(&"metal", "Metall", MaterialDef.MaterialType.METAL, 0.6, 0.45, 0.7, &"metal", &"dent", 7.8)
	_mat(&"glass", "Glas", MaterialDef.MaterialType.GLASS, 0.5, 0.4, 3.2, &"glass", &"shatter", 2.5)
	_mat(&"plastic", "Plastik", MaterialDef.MaterialType.PLASTIC, 0.75, 0.5, 0.6, &"plastic", &"crack", 0.95)
	_mat(&"fabric", "Stoff", MaterialDef.MaterialType.FABRIC, 0.95, 0.75, 0.35, &"soft", &"tear", 0.2)
	_mat(&"ceramic", "Keramik", MaterialDef.MaterialType.CERAMIC, 0.7, 0.4, 2.6, &"ceramic", &"shatter", 2.3)
	_mat(&"rubber", "Gummi", MaterialDef.MaterialType.RUBBER, 1.15, 0.85, 0.25, &"soft", &"bounce", 1.1)
	_mat(&"concrete", "Beton", MaterialDef.MaterialType.CONCRETE, 0.9, 0.7, 0.5, &"stone", &"chip", 2.4)
	_mat(&"asphalt", "Asphalt", MaterialDef.MaterialType.ASPHALT, 0.95, 0.62, 0.5, &"stone", &"chip", 2.3)
	_mat(&"electronics", "Elektronik", MaterialDef.MaterialType.PLASTIC, 0.7, 0.5, 2.4, &"electronic", &"break", 1.4)
	_mat(&"cardboard", "Karton", MaterialDef.MaterialType.FABRIC, 0.9, 0.6, 0.2, &"cardboard", &"dent", 0.12)

func _build_damage_and_economy() -> void:
	damage_settings = DamageSettings.new()
	economy_settings = EconomySettings.new()

# ------------------------------------------------------------ furniture --

func _fur(id: StringName, name_s: String, cat: StringName, mat: StringName, mass: float,
		size: FurnitureData.SizeClass, he: Vector3, value: float, frag: float,
		haulers: int = 1, col: Color = Color(0.7, 0.5, 0.35), com: Vector3 = Vector3.ZERO,
		glass: float = 0.0, rarity: int = 0) -> void:
	var f := FurnitureData.new()
	f.id = id; f.display_name = name_s; f.category = cat; f.material = materials.get(mat)
	f.mass_kg = mass; f.size_class = size; f.half_extents = he
	f.item_value = value; f.purchase_price = value * 0.8; f.fragility = frag
	f.required_haulers = haulers; f.base_color = col
	f.center_of_mass_offset = com; f.breakable_glass_area = glass; f.rarity = rarity
	furniture[id] = f

func _build_furniture() -> void:
	var S := FurnitureData.SizeClass
	_fur(&"cardboard_small", "Karton S", &"generic", &"cardboard", 8, S.TINY, Vector3(0.25, 0.22, 0.25), 15, 0.3, 1, Color(0.82, 0.66, 0.45))
	_fur(&"cardboard_big", "Karton XL", &"generic", &"cardboard", 22, S.SMALL, Vector3(0.35, 0.34, 0.35), 30, 0.35, 1, Color(0.8, 0.64, 0.43))
	_fur(&"books_stack", "Bücherstapel", &"decor", &"paper" if materials.has(&"paper") else &"wood", 14, S.TINY, Vector3(0.22, 0.16, 0.16), 60, 0.5, 1, Color(0.5, 0.3, 0.25))
	_fur(&"lamp", "Stehlampe", &"decor", &"metal", 9, S.SMALL, Vector3(0.18, 0.65, 0.18), 45, 1.1, 1, Color(0.85, 0.75, 0.4))
	_fur(&"plant", "Zimmerpflanze", &"decor", &"ceramic", 12, S.SMALL, Vector3(0.24, 0.4, 0.24), 35, 0.9, 1, Color(0.3, 0.65, 0.3))
	_fur(&"vase", "Oma-Vase", &"decor", &"ceramic", 5, S.TINY, Vector3(0.12, 0.22, 0.12), 450, 2.8, 1, Color(0.9, 0.35, 0.5), Vector3.ZERO, 0.0, 2)
	_fur(&"chair_wood", "Holzstuhl", &"seating", &"wood", 16, S.SMALL, Vector3(0.24, 0.45, 0.24), 70, 0.9, 1, Color(0.6, 0.4, 0.25))
	_fur(&"office_chair", "Bürostuhl", &"seating", &"plastic", 18, S.SMALL, Vector3(0.28, 0.5, 0.28), 120, 0.8, 1, Color(0.2, 0.2, 0.22))
	_fur(&"table_small", "Beistelltisch", &"table" if false else &"generic", &"wood", 25, S.MEDIUM, Vector3(0.45, 0.36, 0.45), 140, 0.9, 1, Color(0.55, 0.38, 0.24))
	_fur(&"dining_table", "Esstisch", &"generic", &"wood", 55, S.LARGE, Vector3(0.9, 0.38, 0.5), 380, 0.8, 2, Color(0.5, 0.35, 0.22), Vector3(0, -0.08, 0))
	_fur(&"sofa_2x", "Zweier-Sofa", &"seating", &"fabric", 60, S.LARGE, Vector3(0.9, 0.42, 0.45), 550, 0.5, 2, Color(0.45, 0.3, 0.6))
	_fur(&"sofa_3x", "Dreier-Sofa", &"seating", &"fabric", 85, S.XLARGE, Vector3(1.15, 0.45, 0.48), 780, 0.5, 2, Color(0.35, 0.45, 0.6))
	_fur(&"bed_single", "Einzelbett", &"bedroom", &"wood", 70, S.XLARGE, Vector3(0.55, 0.4, 1.1), 420, 0.6, 2, Color(0.6, 0.45, 0.4))
	_fur(&"wardrobe", "Kleiderschrank", &"storage", &"wood", 110, S.HUGE, Vector3(0.65, 1.15, 0.35), 650, 0.7, 2, Color(0.45, 0.3, 0.2), Vector3(0, -0.25, 0))
	_fur(&"bookshelf", "Regal", &"storage", &"wood", 65, S.LARGE, Vector3(0.55, 0.9, 0.16), 260, 0.85, 1, Color(0.52, 0.36, 0.23))
	_fur(&"fridge", "Kühlschrank", &"appliance", &"metal", 95, S.XLARGE, Vector3(0.38, 0.9, 0.38), 700, 0.9, 2, Color(0.82, 0.84, 0.86), Vector3(0, -0.3, 0))
	_fur(&"washing_machine", "Waschmaschine", &"appliance", &"metal", 72, S.LARGE, Vector3(0.32, 0.45, 0.32), 480, 1.15, 2, Color(0.88, 0.89, 0.9), Vector3(0, -0.25, 0))
	_fur(&"tv_55", "TV 55\" ", &"electronics", &"electronics", 21, S.MEDIUM, Vector3(0.66, 0.4, 0.08), 950, 2.4, 1, Color(0.08, 0.08, 0.1), Vector3.ZERO, 0.65)
	_fur(&"piano", "Klavier", &"special", &"wood", 210, S.HUGE, Vector3(0.78, 0.75, 0.65), 3200, 1.1, 3, Color(0.1, 0.09, 0.09), Vector3(0, -0.15, -0.12), 0.0, 1)
	_fur(&"safe", "Goldtresor", &"special", &"metal", 640, S.HUGE, Vector3(0.55, 0.6, 0.5), 8000, 0.45, 4, Color(0.35, 0.33, 0.3), Vector3(0, -0.35, 0), 0.0, 3)
	_fur(&"aquarium_big", "Riesenaquarium", &"special", &"glass", 380, S.HUGE, Vector3(0.9, 0.5, 0.45), 5200, 3.4, 2, Color(0.4, 0.75, 0.85), Vector3(0, 0.1, 0), 0.9, 2)
	_fur(&"server_rack", "Server-Rack", &"special", &"metal", 160, S.LARGE, Vector3(0.32, 1.0, 0.4), 4200, 1.8, 2, Color(0.12, 0.13, 0.16), Vector3(0, -0.4, 0), 0.0, 2)
	_fur(&"golden_toilet", "Goldene Toilette", &"special", &"ceramic", 90, S.LARGE, Vector3(0.28, 0.4, 0.38), 12000, 1.4, 1, Color(1.0, 0.78, 0.2), Vector3.ZERO, 0.0, 4)
	_fur(&"garden_gnome_giant", "Riesen-Gartenzwerg", &"decor", &"ceramic", 48, S.MEDIUM, Vector3(0.3, 0.6, 0.3), 66, 1.0, 1, Color(0.9, 0.25, 0.2), Vector3.ZERO, 0.0, 3)

# ------------------------------------------------------------ vehicles --

func _veh(id: StringName, name_s: String, price: float, lvl: int, mass: float, cargo: float,
		body: Vector3, cargo_size: Vector3, cargo_off: Vector3, power: float, top: float,
		brake: float, grip: float, sus: float) -> VehicleData:
	var v := VehicleData.new()
	v.id = id; v.display_name = name_s; v.purchase_price = price; v.required_company_level = lvl
	v.chassis_mass_kg = mass; v.max_cargo_mass_kg = cargo
	v.body_half_extents = body
	v.cargo_area_size = cargo_size; v.cargo_area_offset = cargo_off
	v.engine_power_n = power; v.top_speed_kmh = top; v.brake_power_n = brake
	v.base_grip = grip; v.suspension_stiffness = sus
	v.primary_color = Color(0.85, 0.55, 0.12) if id == &"starter_truck" else Color(0.8, 0.82, 0.85)
	vehicles[id] = v
	return v

func _build_vehicles() -> void:
	_veh(&"starter_truck", "Alter Möbellaster \"Betty\"", 0, 1, 2300, 1200,
		Vector3(1.1, 0.72, 2.4), Vector3(2.0, 1.5, 3.0), Vector3(0, 0.9, 2.2), 9000, 88, 15000, 1.0, 50)
	_veh(&"small_van", "Kleiner Transporter \"Flitzer\"", 4500, 2, 1600, 800,
		Vector3(0.95, 0.85, 2.0), Vector3(1.7, 1.35, 2.4), Vector3(0, 0.85, 1.6), 8200, 105, 13500, 1.05, 55)
	_veh(&"furniture_lorry", "Möbelwagen \"Wumms\"", 12000, 3, 3400, 2600,
		Vector3(1.2, 0.95, 2.9), Vector3(2.3, 2.0, 4.2), Vector3(0, 1.2, 2.6), 14000, 82, 22000, 1.0, 68)
	_veh(&"heavy_truck", "Heavy-Duty \"Titan\"", 28000, 5, 5200, 5200,
		Vector3(1.3, 1.05, 3.2), Vector3(2.5, 2.1, 4.6), Vector3(0, 1.3, 2.9), 22000, 75, 30000, 1.0, 85)
	_veh(&"forklift", "Gabelstapler \"Stöpsel\"", 6500, 2, 1900, 900,
		Vector3(0.8, 0.7, 1.5), Vector3(1.3, 0.08, 1.1), Vector3(0, 0.2, 1.6), 6500, 25, 9000, 1.2, 70)

# ------------------------------------------------------------ cosmetics --

func _cos(id: StringName, name_s: String, slot: CosmeticData.Slot, price: float, lvl: int,
		attach: StringName, style: StringName, col: Color, phys: bool = false, segs: int = 0,
		tags: PackedStringArray = PackedStringArray()) -> void:
	var c := CosmeticData.new()
	c.id = id; c.display_name = name_s; c.slot = slot; c.price = price
	c.unlock_company_level = lvl; c.attach_node = attach; c.procedural_style = style
	c.color = col; c.is_physical = phys; c.physical_segments = segs; c.tags = tags
	cosmetics[id] = c

func _build_cosmetics() -> void:
	var H := CosmeticData.Slot
	_cos(&"cap", "Baseball-Cap", H.HAT, 25, 0, &"Head", &"cap", Color(0.2, 0.4, 0.8))
	_cos(&"sombrero", "RIESENGER Sombrero", H.HAT, 85, 1, &"Head", &"sombrero", Color(0.9, 0.75, 0.2), false, 0, PackedStringArray(["funny"]))
	_cos(&"cowboy", "Cowboyhut 'El Pollo'", H.HAT, 60, 1, &"Head", &"cowboy", Color(0.45, 0.3, 0.18), false, 0, PackedStringArray(["funny"]))
	_cos(&"beanie", "Bommelmütze", H.HAT, 15, 0, &"Head", &"beanie", Color(0.8, 0.2, 0.3))
	_cos(&"santa_hat", "Weihnachtsmütze", H.HAT, 30, 0, &"Head", &"santa", Color(0.85, 0.1, 0.1), false, 0, PackedStringArray(["seasonal"]))
	_cos(&"sunglasses", "Coole Sonnenbrille", H.FACE, 35, 0, &"Head", &"glasses", Color(0.1, 0.1, 0.12))
	_cos(&"neon_glasses", "Neon-Röhrenbrille", H.FACE, 55, 2, &"Head", &"neon_glasses", Color(0.2, 1.0, 0.9), false, 0, PackedStringArray(["funny"]))
	_cos(&"headphones", "Riesen-Kopfhörer", H.NECK, 70, 1, &"Head", &"headphones", Color(0.15, 0.15, 0.18))
	_cos(&"scarf_red", "Langer roter Schal", H.NECK, 45, 1, &"Neck", &"scarf", Color(0.8, 0.12, 0.12), true, 6, PackedStringArray(["funny", "physics"]))
	_cos(&"hi_vis", "Warne Weste", H.TORSO, 40, 0, &"Torso", &"vest", Color(0.95, 0.7, 0.05))
	_cos(&"overall", "Mechaniker-Overall", H.TORSO, 95, 2, &"Torso", &"overall", Color(0.25, 0.35, 0.55))
	_cos(&"tool_belt", "Werkzeuggürtel", H.LEGS, 120, 1, &"Hips", &"belt", Color(0.35, 0.22, 0.1))
	_cos(&"backpack", "Liefer-Rucksack", H.BACK, 80, 1, &"Torso", &"backpack", Color(0.3, 0.5, 0.3))
	_cos(&"giant_boots", "Riiiieeeese Stiefel", H.LEGS, 65, 2, &"Feet", &"boots", Color(0.3, 0.18, 0.1), false, 0, PackedStringArray(["funny"]))
	_cos(&"wrestling_mask", "Ringschmasken-Maske", H.FACE, 150, 3, &"Head", &"mask", Color(0.7, 0.1, 0.6), false, 0, PackedStringArray(["funny", "rare"]))

# ------------------------------------------------------------ build pieces --

func _piece(id: StringName, name_s: String, kind: BuildPieceData.Kind, cost: float, lvl: int,
		footprint: Vector2i, h: float, qual: float, mat: StringName) -> void:
	var b := BuildPieceData.new()
	b.id = id; b.display_name = name_s; b.kind = kind; b.cost = cost
	b.required_company_level = lvl; b.grid_footprint = footprint; b.height_m = h
	b.hq_quality_score = qual; b.material = materials.get(mat)
	build_pieces[id] = b

func _build_pieces() -> void:
	var K := BuildPieceData.Kind
	_piece(&"wall_basic", "Standardwand", K.WALL, 120, 0, Vector2i(2, 1), 2.6, 0.6, &"concrete")
	_piece(&"wall_lux", "Luxus-Wandpaneel", K.WALL, 420, 3, Vector2i(2, 1), 2.6, 1.4, &"wood")
	_piece(&"floor_basic", "Boden (Teppich-Rest)", K.FLOOR, 80, 0, Vector2i(2, 2), 0.08, 0.5, &"wood")
	_piece(&"floor_parquet", "Parkett", K.FLOOR, 260, 2, Vector2i(2, 2), 0.08, 1.2, &"wood")
	_piece(&"ceiling_plain", "Decke", K.CEILING, 90, 0, Vector2i(2, 2), 0.1, 0.4, &"concrete")
	_piece(&"door_wood", "Holztür", K.DOOR, 180, 0, Vector2i(2, 1), 2.1, 0.8, &"wood")
	_piece(&"window_basic", "Fenster", K.WINDOW, 150, 0, Vector2i(2, 1), 1.2, 0.7, &"glass")
	_piece(&"stair_wood", "Treppe", K.STAIR, 300, 1, Vector2i(2, 3), 2.6, 0.7, &"wood")
	_piece(&"lamp_ceiling", "Deckenlampe", K.LIGHT, 60, 0, Vector2i(1, 1), 0.15, 0.9, &"metal")
	_piece(&"plant_corner", "Ecks-Pflanze", K.DECOR, 35, 0, Vector2i(1, 1), 0.8, 0.5, &"fabric")
	_piece(&"desk_work", "Schreibtisch", K.WORKBENCH, 220, 0, Vector2i(2, 1), 0.75, 1.0, &"wood")
	_piece(&"break_sofa", "Pausen-Sofa", K.DECOR, 480, 2, Vector2i(2, 1), 0.8, 1.6, &"fabric")
	_piece(&"fridge_break", "Küchen-Kühlschrank", K.WORKBENCH, 380, 1, Vector2i(1, 1), 0.9, 1.3, &"metal")

# ------------------------------------------------------------ upgrades --

func _upg(id: StringName, name_s: String, cat: UpgradeData.Category, cost: float, lvl: int, mods: Dictionary) -> void:
	var u := UpgradeData.new()
	u.id = id; u.display_name = name_s; u.category = cat; u.cost = cost
	u.required_company_level = lvl; u.modifiers = mods
	upgrades[id] = u

func _build_upgrades() -> void:
	var C := UpgradeData.Category
	_upg(&"engine_1", "Motor: Nockenwelle B", C.ENGINE, 900, 1, {"engine_power_n": {"mult": 1.3}, "top_speed_kmh": {"mult": 1.12}})
	_upg(&"engine_2", "Motor: Turbolader \"Schnarchweg\"", C.ENGINE, 2600, 3, {"engine_power_n": {"mult": 1.45}, "max_cargo_mass_kg": {"mult": 1.1}})
	_upg(&"susp_1", "Federung: verstärkt", C.SUSPENSION, 650, 1, {"suspension_stiffness": {"mult": 1.25}, "damping_ratio": {"add": 0.08}})
	_upg(&"susp_2", "Federung: Heavy Duty", C.SUSPENSION, 1800, 3, {"suspension_stiffness": {"mult": 1.55}, "anti_roll_stiffness": {"mult": 1.4}})
	_upg(&"tires_grip", "Reifen: Grip", C.WHEELS, 550, 1, {"base_grip": {"mult": 1.25}})
	_upg(&"tires_rain", "Reifen: Regen", C.WHEELS, 750, 2, {"wet_grip_mult": {"set": 1.35}})
	_upg(&"tires_heavy", "Reifen: Heavy Load", C.WHEELS, 950, 3, {"max_cargo_mass_kg": {"mult": 1.2}})
	_upg(&"cargo_ext", "Ladefläche: Hochzieh-Kit", C.CARGO_AREA, 1200, 2, {"cargo_area_size": {"vector_add": [0, 0.5, 0.7]}})
	_upg(&"horn_air", "Druckluftsirene", C.HORN, 180, 1, {})
	_upg(&"horn_organ", "LKW-Bordorgel (Humor)", C.HORN, 95, 0, {})
	_upg(&"lights_led", "LED-Balken", C.LIGHTS, 320, 2, {})
	_upg(&"paint_gloss", "Lack: Glossy", C.PAINT, 240, 1, {})
	_upg(&"ad_local", "Firmenschild streichen", C.COMPANY, 500, 1, {})

# ------------------------------------------------------------ .tres Overlay --

func _overlay_from_definitions() -> void:
	var mapping := {
		"res://data/definitions/furniture": "furniture",
		"res://data/definitions/vehicles": "vehicles",
		"res://data/definitions/missions": "missions",
		"res://data/definitions/cosmetics": "cosmetics",
		"res://data/definitions/build": "build_pieces",
		"res://data/definitions/upgrades": "upgrades",
	}
	for dir in mapping:
		var target_dict: Dictionary = get(mapping[dir])
		var da := DirAccess.open(dir)
		if da == null:
			continue
		da.list_dir_begin()
		var fname := da.get_next()
		while fname != "":
			if not fname.begins_with(".") and fname.ends_with(".tres"):
				var res: Resource = load(dir.path_join(fname))
				if res != null and res.get("id") != null and res.get("id") != &"":
					target_dict[res.get("id")] = res
			fname = da.get_next()
		da.list_dir_end()
	# Missions-Extras: zusätzlich generierte Pool-Varianten
	_build_generated_missions()

# ------------------------------------------------------------ missions --

var _mission_counter := 0

func register_generated_mission(m: MissionData) -> void:
	missions[m.mission_id] = m

func make_mission_id() -> String:
	_mission_counter += 1
	return "job_%03d" % _mission_counter

func _build_generated_missions() -> void:
	## Hand-authored Content für den Slice + Specials.
	var m1 := MissionData.new()
	m1.mission_id = &"job_studenzimmer"; m1.display_name = "Student zieht in WG"
	m1.client_name = "Kevin (3.)"; m1.client_type = &"student"
	m1.description = "Kleines Budget, kleines Zimmer, großes Chaos-Potenzial."
	m1.furniture_manifest = _manifest([furniture[&"cardboard_small"], furniture[&"cardboard_small"], furniture[&"chair_wood"], furniture[&"lamp"], furniture[&"bookshelf"], furniture[&"bed_single"]])
	m1.base_payment = 420; m1.time_limit_seconds = 480; m1.difficulty = MissionData.Difficulty.EASY
	missions[m1.mission_id] = m1

	var m2 := MissionData.new()
	m2.mission_id = &"job_familie"; m2.display_name = "Familie Bergmann, 3 Zimmer"
	m2.client_name = "Familie Bergmann"; m2.client_type = &"family"
	m2.description = "Mehr Möbel, mehr Chancen. Der Esstisch ist schwer."
	m2.furniture_manifest = _manifest([
		furniture[&"dining_table"], furniture[&"sofa_2x"], furniture[&"wardrobe"],
		furniture[&"fridge"], furniture[&"washing_machine"], furniture[&"tv_55"],
		furniture[&"plant"], furniture[&"chair_wood"], furniture[&"chair_wood"],
	])
	m2.base_payment = 1450; m2.time_limit_seconds = 900; m2.difficulty = MissionData.Difficulty.NORMAL
	m2.objectives = _objlist([_obj(&"tv_safe", "Der 55\" darf keinen Kratzer abbekommen", &"no_damage_on", 0, false, 150, {"furniture_id": &"tv_55", "max_damage": 5.0})])
	missions[m2.mission_id] = m2

	var m3 := MissionData.new()
	m3.mission_id = &"job_bank"; m3.display_name = "Bank-Räumung: Tresor Nr. 7"
	m3.client_name = "Sparkasse Zwickau-Ost"; m3.client_type = &"business"
	m3.description = "640 kg pure Verantwortung. Verteil die Last, sonst nickt Betty."
	m3.furniture_manifest = _manifest([furniture[&"safe"], furniture[&"office_chair"], furniture[&"desk_work"] if furniture.has(&"desk_work") else furniture[&"table_small"], furniture[&"cardboard_big"]])
	m3.base_payment = 3600; m3.time_limit_seconds = 1200; m3.damage_multiplier = 0.85
	m3.difficulty = MissionData.Difficulty.HARD; m3.min_company_level = 2; m3.min_reputation = 25
	m3.special_rules = PackedStringArray(["weight_balancing"])
	m3.objectives = _objlist([_obj(&"load_safe", "Tresor gesichert im Truck verladen", &"load_vehicle", 1, false, 0, {"furniture_id": &"safe", "need_straps": 2}),
		_obj(&"no_tipsy", "Truck darf nicht kippen", &"no_tip", 0, true, 300, {})])
	missions[m3.mission_id] = m3

	var m4 := MissionData.new()
	m4.mission_id = &"job_haunted"; m4.display_name = "Das Spukhaus"
	m4.client_name = "Nachlass R. Grimm"; m4.client_type = &"eccentric"
	m4.description = "Nacht. Nebel. Die Möbel haben eigene Pläne."
	m4.furniture_manifest = _manifest([furniture[&"piano"], furniture[&"vase"], furniture[&"wardrobe"], furniture[&"lamp"], furniture[&"chair_wood"]])
	m4.base_payment = 2800; m4.time_limit_seconds = 1000; m4.damage_multiplier = 1.35
	m4.difficulty = MissionData.Difficulty.HARD; m4.min_company_level = 2; m4.force_night = true
	m4.special_rules = PackedStringArray(["haunted"])
	missions[m4.mission_id] = m4

	var m5 := MissionData.new()
	m5.mission_id = &"job_tower30"; m5.display_name = "Wolkenkratzer, Etage 30"
	m5.client_name = "Apex Tower Management"; m5.client_type = &"business"
	m5.description = "Aufzug kaputt. Kran. Wind. Viel Spaß mit dem Sofa da draußen."
	m5.furniture_manifest = _manifest([furniture[&"sofa_3x"], furniture[&"tv_55"], furniture[&"plant"]])
	m5.base_payment = 5200; m5.time_limit_seconds = 1500; m5.damage_multiplier = 1.5
	m5.difficulty = MissionData.Difficulty.EXTREME; m5.min_company_level = 3; m5.min_reputation = 45
	m5.special_rules = PackedStringArray(["crane", "high_wind"])
	missions[m5.mission_id] = m5

	var m6 := MissionData.new()
	m6.mission_id = &"job_messie"; m6.display_name = "Die Messi-Wohnung"
	m6.client_name = "Amt für Zwangsentrümpelung"; m6.client_type = &"business"
	m6.description = "40 Kartons. Ein Besen. Ein Traum."
	var many: Array[FurnitureData] = []
	for i in 12:
		many.append(furniture[&"cardboard_small"])
	many.append(furniture[&"cardboard_big"])
	many.append(furniture[&"lamp"])
	m6.furniture_manifest = many
	m6.base_payment = 900; m6.time_limit_seconds = 900; m6.damage_multiplier = 0.6
	m6.difficulty = MissionData.Difficulty.NORMAL; m6.min_company_level = 1
	m6.special_rules = PackedStringArray(["messy_hoard"])
	missions[m6.mission_id] = m6

func _manifest(items: Array) -> Array[FurnitureData]:
	## Baut typisierte Arrays (Godot 4: keine as-Casts von untyped auf typed).
	var out: Array[FurnitureData] = []
	for it in items:
		if it is FurnitureData:
			out.append(it)
		else:
			push_warning("Content: Möbel-Manifest-Eintrag ungültig: %s" % str(it))
	return out

func _objlist(objs: Array) -> Array[ObjectiveData]:
	var out: Array[ObjectiveData] = []
	for o in objs:
		if o is ObjectiveData:
			out.append(o)
	return out

func _obj(id: StringName, desc: String, type: StringName, count: int, opt: bool, bonus: float, p: Dictionary) -> ObjectiveData:
	var o := ObjectiveData.new()
	o.id = id; o.description = desc; o.type = type
	o.required_count = count; o.optional = opt; o.bonus_money = bonus; o.params = p
	return o
