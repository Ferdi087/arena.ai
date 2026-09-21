extends Node3D
class_name WorldRoot
## Basis jeder SPIEL-Welt (Stadt-Slice, HQ, Test-Arenen). #76/#91/#114.
##
## Verantwortlich für:
##  * Welt-Environment (Sonne, WorldEnvironment-> Settings-Registrierung)
##  * Spieler-Spawning inkl. lokalem Split-Screen + Multiplayer (Spawner)
##  * Truck- & Furniture-Spawns (Host-authoritativ, repliziert)
##  * Chunk-Streaming-Hooks, Save-Contributor "world"
##  * Gruppen: "world"
##
## Kinder zur Laufzeit:
##   World/Environment, Ground, City, HQPad, JobZones, Units/(Players+Furniture
##   +Vehicles), Weather(MissionRuntime/ChunkManager/Traffic/NPCs/DayNight)

@export_enum("city_test", "hq", "grab_arena", "vehicle_arena") var world_kind: String = "city_test"
@export var spawn_players: int = 1
@export var ground_color := Color(0.30, 0.34, 0.30)
@export var truck_vehicle_id: StringName = &"starter_truck"

var sun: DirectionalLight3D = null
var world_env: WorldEnvironment = null
var players: Dictionary[int, Player] = {}
var vehicle: VehicleController = null
var mission_runtime: MissionRuntime = null
var chunk_manager: ChunkManager = null
var traffic: TrafficManager = null
var day_night: DayNightCycle = null
var weather: WeatherController = null
var _units_root: Node3D = null
var _furniture_root: Node3D = null
var _furniture_spawner: MultiplayerSpawner = null
var _player_spawner: MultiplayerSpawner = null
var _mission_items: Array[FurnitureBody] = []
var _street_lights: Array[OmniLight3D] = []

var save_key: String = "world"

func _enter_tree() -> void:
	add_to_group("world")

func _ready() -> void:
	Saves.register_contributor(self)
	tree_exiting.connect(func() -> void: Saves.unregister_contributor(self))
	_build_environment()
	_build_ground()
	if world_kind == "city_test":
		_build_city_slice()
	_build_units_root()
	_spawn_truck()
	_setup_weather_systems()
	_setup_multiplayer_spawners()
	var local_count := 1 if Net.is_online() else maxi(spawn_players, 1)
	if world_kind == "grab_arena" or world_kind == "vehicle_arena":
		_spawn_arena_players()
	else:
		for i in local_count:
			_spawn_local_player(i)
	# Nach 1 Frame: Clients fragen Host-Spawn an (Szene ist dann geladen).
	await get_tree().process_frame
	if UI.hud == null:
		UI.attach_hud()
	if Net.is_online():
		announce_self.rpc_id(Net.server_peer_id())
	EventBus.player_exited_vehicle.connect(_on_player_exited_vehicle_check)

# ---------------------------------------------------------------- Environ --

func _build_environment() -> void:
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var proc := ProceduralSkyMaterial.new()
	proc.sky_top_color = Color(0.42, 0.6, 0.85)
	proc.sky_horizon_color = Color(0.72, 0.8, 0.88)
	proc.ground_bottom_color = Color(0.2, 0.22, 0.24)
	proc.ground_horizon_color = Color(0.72, 0.8, 0.88)
	sky.sky_material = proc
	env.background_sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.8, 0.85)
	env.fog_density = 0.0035
	env.directional_shadow_max_distance = 70.0
	world_env.environment = env
	add_child(world_env)
	Settings.register_world_environment(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-46, 24, 0)
	add_child(sun)

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := WorldBoundaryShape3D.new()
	cs.shape = shape
	ground.add_child(cs)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	mi.mesh = plane
	var style := get_node_or_null(^"/root/Style") as StyleService
	var m: StandardMaterial3D = style.get_flat_material(&"ground", ground_color, 0.95) if style != null else StandardMaterial3D.new()
	if style == null:
		m.albedo_color = ground_color
	mi.material_override = m
	ground.add_child(mi)
	add_child(ground)

# ------------------------------------------------------------- City Slice --

func _build_city_slice() -> void:
	var city := Node3D.new()
	city.name = "City"
	add_child(city)
	var style := get_node_or_null(^"/root/Style") as StyleService
	var road_mat: StandardMaterial3D = style.get_flat_material(&"asphalt", Color(0.16, 0.17, 0.19), 0.98) if style != null else StandardMaterial3D.new()
	# Straßenraster
	for i in CityLayout.GRID:
		for j in CityLayout.GRID:
			var p := CityLayout.node_pos(i, j)
			var road := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(CityLayout.SPACING, CityLayout.ROAD_WIDTH)
			road.mesh = pm
			road.material_override = road_mat
			road.position = p + Vector3(0, 0.01, 0)
			city.add_child(road)
			var road2 := road.duplicate() as MeshInstance3D
			road2.rotate_object_local(Vector3(0, 1, 0), PI / 2)
			road2.position = p + Vector3(0, 0.012, 0)
			city.add_child(road2)
	# Häuser/Blöcke als Boxen (später: GridMap/MultiMesh + Chunks #24)
	var w := randf()
	for i in CityLayout.GRID - 1:
		for j in CityLayout.GRID - 1:
			var center := CityLayout.node_pos(i, j) + Vector3(CityLayout.SPACING * 0.5, 0, CityLayout.SPACING * 0.5)
			var district := CityLayout.district_at(Vector2i(i, j))
			var h := 4.0
			match district:
				CityLayout.District.DOWNTOWN: h = randf_range(10.0, 26.0)
				CityLayout.District.INDUSTRY: h = randf_range(3.5, 7.0)
				CityLayout.District.VILLA: h = 3.4
				CityLayout.District.PARK:
					continue
				_: h = randf_range(3.0, 6.5)
			if absf(center.x) < CityLayout.SPACING * 0.7 and absf(center.z) < CityLayout.SPACING * 0.7:
				continue  # mittlere Fläche = unser HQ-Parkplatz bleibt frei
			_add_block(city, center, Vector3(randf_range(7.0, 10.5), h, randf_range(7.0, 10.5)), district, style)
	# Laternen (Nacht!) – simple Omnis an Kreuzungen im Radius
	for i in range(0, CityLayout.GRID, 2):
		for j in range(0, CityLayout.GRID, 2):
			var p := CityLayout.node_pos(i, j) + Vector3(2.2, 4.4, 2.2)
			var lamp := OmniLight3D.new()
			lamp.omni_range = 9.0
			lamp.light_energy = 0.0
			lamp.light_color = Color(1.0, 0.86, 0.55)
			lamp.position = p
			city.add_child(lamp)
			_street_lights.append(lamp)
			var pole := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.16, 4.4, 0.16)
			pole.mesh = bm
			pole.position = p - Vector3(0, 2.2, 0)
			city.add_child(pole)

func _add_block(parent: Node3D, center: Vector3, size: Vector3, district: int, style: StyleService) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var col := Color(0.55, 0.5, 0.44)
	match district:
		CityLayout.District.DOWNTOWN: col = Color(0.42, 0.46, 0.55)
		CityLayout.District.INDUSTRY: col = Color(0.5, 0.45, 0.38)
		CityLayout.District.VILLA: col = Color(0.68, 0.62, 0.5)
		CityLayout.District.HARBOR: col = Color(0.45, 0.48, 0.5)
	if style != null:
		mi.material_override = style.get_flat_material(StringName("blk%d" % (int(size.x * 10) % 7)), col, 0.9)
	body.add_child(mi)
	parent.add_child(body)

# ---------------------------------------------------------------- Units --

func _build_units_root() -> void:
	_units_root = Node3D.new()
	_units_root.name = "Units"
	add_child(_units_root)
	_furniture_root = Node3D.new()
	_furniture_root.name = "Furniture"
	_units_root.add_child(_furniture_root)

func _spawn_local_player(index: int) -> void:
	if Net.is_online() and Net.is_authority():
		_host_spawn_player(multiplayer.get_unique_id(), index)
	elif Net.is_online():
		# Client bittet Host (spawn_relay_done in announce_self):
		pass
	else:
		var p := _create_player(index, 1, false)
		p.global_position = Vector3(index * 2.0, 1.2, 6.0)
		if index == 0:
			Characters.apply_to_player(p)
		if Game.local_coop_players > 1 and index == 1:
			SplitScreen.attach(p, index)

func _create_player(index: int, peer: int, as_proxy: bool) -> Player:
	var pl := Player.new()
	pl.name = "Player_%d" % (peer if Net.is_online() else index)
	pl.player_index = index
	pl.network_peer_id = peer
	pl.is_online_proxy = as_proxy
	pl.display_name = "P%d" % (index + 1)
	_units_root.add_child(pl)
	if Net.is_online():
		pl.set_multiplayer_authority(peer)
	players[peer if Net.is_online() else index] = pl
	return pl

func _host_spawn_player(peer_id: int, index: int) -> Player:
	return _create_player(index, peer_id, false)

## Split-Screen-Handler ruft das für Index > 0.
func ensure_local_second_player() -> void:
	if Net.is_online():
		return
	var second := _create_player(1, 1, false)
	second.global_position = Vector3(2.2, 1.2, 6.0)
	SplitScreen.attach(second, 1)

func _spawn_arena_players() -> void:
	for i in spawn_players:
		var p := _create_player(i, 1, false)
		p.global_position = Vector3(i * 1.8 - 0.9, 1.2, 4.5)
		Characters.apply_to_player(p)

func _spawn_truck() -> void:
	if Net.is_online() and not Net.is_authority():
		return
	vehicle = VehicleController.new()
	vehicle.name = "Truck"
	vehicle.data = Content.get_vehicle(truck_vehicle_id)
	vehicle.position = Vector3(4.5, 0.8, 2.0)
	_units_root.add_child(vehicle)
	EventBus.player_entered_vehicle.connect(_on_player_entered_vehicle)

func find_vehicle() -> VehicleController:
	return vehicle

func find_nearest_vehicle(pos: Vector3) -> VehicleController:
	var best: VehicleController = null
	var bd := INF
	for v in get_tree().get_nodes_in_group("vehicles"):
		var vc := v as VehicleController
		if vc == null:
			continue
		var d := vc.global_position.distance_squared_to(pos)
		if d < bd:
			bd = d
			best = vc
	return best

func _on_player_entered_vehicle(v: VehicleController, p: Player) -> void:
	vehicle = v
	if p != null and p.get_rig() != null:
		p.get_rig().enter_vehicle_mode(v, 0)

func _on_player_exited_vehicle_check(_v: VehicleController, _p: Node) -> void:
	pass

# ------------------------------------------------------- Furniture API --

func spawn_furniture(data: FurnitureData, pos: Vector3) -> FurnitureBody:
	if Net.is_online() and not Net.is_authority():
		request_furniture_spawn.rpc_id(Net.server_peer_id(), data.id, pos)
		return null
	return _instantiate_furniture(data, pos)

@rpc("any_peer", "call_remote", "reliable")
func request_furniture_spawn(fid: StringName, pos: Vector3) -> void:
	if not Net.is_authority():
		return
	var data: FurnitureData = Content.get_furniture(fid)
	if data != null:
		_instantiate_furniture(data, pos)

func _instantiate_furniture(data: FurnitureData, pos: Vector3) -> FurnitureBody:
	var fb := FurnitureBody.new()
	fb.name = "Furn_%s" % String(data.id)
	_furniture_root.add_child(fb)
	fb.setup(data)
	fb.global_position = pos
	return fb

func spawn_mission_manifest(m: MissionData, at: Vector3) -> void:
	clear_mission_items()
	var i := 0
	var cols := 3
	for f in m.furniture_manifest:
		var jitter := Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
		var cell := Vector3(float(i % cols) * 1.6 - 1.6, 0, float(i / cols) * 1.4)
		var fb := _instantiate_furniture(f, at + cell + jitter)
		_mission_items.append(fb)
		i += 1
		Company.catalog_collect(f)
	UI.toast("Möbel bereitgestellt: %d Stück" % m.furniture_manifest.size())

func clear_mission_items() -> void:
	for b in _mission_items:
		if is_instance_valid(b):
			if b.locked_in_cargo and vehicle != null:
				vehicle.remove_cargo_item(b)
			b.queue_free()
	_mission_items.clear()

func spawn_debris_pile(count: int, at: Vector3) -> int:
	var spawned := 0
	for i in count:
		var fb := _instantiate_furniture(Content.get_furniture(&"cardboard_small"), at + Vector3(randf_range(-4, 4), 0.6, randf_range(-4, 4)))
		_mission_items.append(fb)
		spawned += 1
	return spawned

# ------------------------------------------------------- Multiplayer hooks --

func _setup_multiplayer_spawners() -> void:
	if not Net.is_online():
		return
	# Player-Spawner: custom spawn_function -> unsere _create_player Logik.
	_player_spawner = MultiplayerSpawner.new()
	_player_spawner.name = "PlayerSpawner"
	_player_spawner.spawn_path = NodePath("..")
	_player_spawner.spawn_function = _mp_spawn_player
	_units_root.add_child(_player_spawner)
	# Furniture-Despawn syncen wir manuell (clear via RPC) – kein Spawner,
	# weil FurnitureBody ohne .tscn prozedural gebaut wird (Architekturentscheidung).
	multiplayer.peer_disconnected.connect(_on_peer_gone)

func _mp_spawn_player(data: Variant) -> Node:
	var d: Dictionary = data if data is Dictionary else {}
	var idx := int(d.get("index", 0))
	var peer := int(d.get("peer", 0))
	return _create_player(idx, peer, peer != multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func announce_self() -> void:
	if not Net.is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	# Host spawned Autoritätsspieler für den neuen Peer + Notify
	var count := _host_player_count()
	_host_spawn_player(sender, count)
	if sender != multiplayer.get_unique_id():
		_broadcast_remote_player.rpc(sender, count)
	Net.register_player(sender, players.get(sender))

func _host_player_count() -> int:
	return players.size()

@rpc("authority", "call_remote", "reliable")
func _broadcast_remote_player(peer: int, index: int) -> void:
	# Clients bauen denselben Proxy wie Host-Playerliste (Spawn-Sync).
	if players.has(peer):
		return
	var p := _create_player(index, peer, true)
	p.global_position = Vector3(0, 1.2, 6.0)
	Net.register_player(peer, p)

func request_player_spawn(peer: int) -> void:
	# von Net._spawn_player_for_peer gerufen (Host-seitig)
	if not Net.is_authority():
		return
	if players.has(peer):
		return
	_host_spawn_player(peer, _host_player_count())
	_broadcast_remote_player.rpc(peer, _host_player_count() - 1)

func _on_peer_gone(peer_id: int) -> void:
	if players.has(peer_id):
		var p := players[peer_id]
		players.erase(peer_id)
		if is_instance_valid(p):
			p.queue_free()
	EventBus.player_left.emit(peer_id)
	for node in get_tree().get_nodes_in_group("furniture"):
		var fb := node as FurnitureBody
		if fb == null:
			continue
		for h in fb.holds.duplicate():
			if h.network_id == peer_id:
				fb.end_hold(h)

# --------------------------------------------------- Systems (Wetter/etc.) --

func _setup_weather_systems() -> void:
	var systems := Node.new()
	systems.name = "Systems"
	add_child(systems)
	day_night = DayNightCycle.new()
	day_night.name = "DayNight"
	day_night.sun = sun
	day_night.street_lights = _street_lights
	systems.add_child(day_night)
	weather = WeatherController.new()
	weather.name = "Weather"
	weather.day_night = day_night
	systems.add_child(weather)
	if world_kind == "city_test":
		chunk_manager = ChunkManager.new()
		chunk_manager.name = "Chunks"
		systems.add_child(chunk_manager)
		traffic = TrafficManager.new()
		traffic.name = "Traffic"
		traffic.city_root = get_node_or_null("City")
		systems.add_child(traffic)
	# Mission runtime (nur Stadt hat Aufträge)
	if world_kind == "city_test":
		mission_runtime = MissionRuntime.new()
		mission_runtime.name = "MissionRuntime"
		mission_runtime.world = self
		systems.add_child(mission_runtime)
		if Missions.has_active_mission():
			mission_runtime._prepare(Missions.active_mission)
			mission_runtime._on_started(Missions.active_mission)

func flicker_lights(duration: float) -> void:
	if day_night != null:
		day_night.call("flicker", duration)

func debug_grab_info() -> String:
	for p in players.values():
		if p != null and not p.is_online_proxy and p.get_node_or_null("Interaction") != null:
			var im := p.get_node_or_null("Interaction") as InteractionManager
			if im != null:
				return im.debug_grab_info()
	return "kein lokaler Spieler"

# ------------------------------------------------------------------ Save --

func save_to_dict() -> Dictionary:
	var items: Array = []
	for b in get_tree().get_nodes_in_group("furniture"):
		var fb := b as FurnitureBody
		if fb == null or not fb.is_in_group("persistent"):
			continue
		var t := fb.global_transform
		items.append({
			"pos": [t.origin.x, t.origin.y, t.origin.z],
			"rot": [t.basis.get_euler().x, t.basis.get_euler().y, t.basis.get_euler().z],
			"data": fb.get_save_data(),
		})
	var veh: Dictionary = {}
	if vehicle != null:
		veh = vehicle.get_save_data()
	return {"furniture": items, "vehicle": veh, "hour": day_night.hour if day_night != null else 8.0}

func apply_save_state(d: Dictionary) -> void:
	for raw in d.get("furniture", []):
		var entry: Dictionary = raw
		var fdata: FurnitureData = Content.get_furniture(StringName(String(entry.get("data", {}).get("fid", ""))))
		if fdata == null:
			continue
		var p: Array = entry.get("pos", [0, 1, 0])
		var fb := _instantiate_furniture(fdata, Vector3(p[0], p[1], p[2]))
		fb.add_to_group("persistent")
		fb.apply_save_data(entry.get("data", {}))
	var veh: Dictionary = d.get("vehicle", {})
	if not veh.is_empty() and vehicle != null:
		vehicle.apply_save_data(veh)
	if day_night != null and d.has("hour"):
		day_night.set_hour(float(d["hour"]))
