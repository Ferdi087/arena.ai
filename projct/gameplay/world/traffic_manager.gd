extends Node
class_name TrafficManager
## Verkehr + Fußgänger mit LOD-Tiers (#23/#77). Bewusst KINEMATISCH und auf
## dem Decor-Layer: Autos dürfen die Physik nicht sprengen (#75/#130). Sie sind
## "lebendige Kulisse" – Kollision mit Player bleibt als Blocker bestehen
## (StaticBody-Körper, die mitbewegt werden, günstig im Server).

const CAR_COUNT := 14
const PED_COUNT := 18

var city_root: Node3D = null
var _cars: Array[Node3D] = []
var _peds: Array[NPCCarrier] = []
var _traffic_density := 1.0

func _ready() -> void:
	_build_cars()
	_build_peds()
	EventBus.time_of_day_changed.connect(_on_time)
	EventBus.weather_changed.connect(_on_weather)

func _on_time(h: float) -> void:
	_traffic_density = 0.4 if (h < 5.5 or h > 22.0) else (1.35 if (h > 7.0 and h < 9.5) or (h > 16.0 and h < 18.5) else 1.0)

func _on_weather(kind: int, _i: float) -> void:
	if kind >= WeatherController.Kind.RAIN:
		_traffic_density *= 0.7

func _build_cars() -> void:
	var root := Node3D.new()
	root.name = "TrafficCars"
	(city_root if city_root != null else get_parent()).add_child(root)
	for i in CAR_COUNT:
		var car := _make_car_visual(i)
		root.add_child(car)
		_cars.append(car)

func _make_car_visual(idx: int) -> Node3D:
	var node := Node3D.new()
	node.name = "Car_%02d" % idx
	node.add_to_group("npcs")
	var style := get_node_or_null(^"/root/Style") as StyleService
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8, 1.2, 3.8)
	mi.mesh = bm
	var col := Color.from_hsv(randf(), 0.55, 0.75)
	mi.material_override = style.get_flat_material(StringName("car_%d" % (idx % 5)), col) if style != null else null
	node.add_child(mi)
	node.position = Vector3(0, 1.0, 0)
	var data := CarPath.new()
	data.route = CityLayout.route(Vector3.ZERO, Vector3(randf_range(-70, 70), 0, randf_range(-70, 70)))
	if data.route.size() < 2:
		data.route = PackedVector3Array([Vector3(-52, 1, -52), Vector3(52, 1, -52), Vector3(52, 1, 52), Vector3(-52, 1, 52), Vector3(-52, 1, -52)])
	data.speed = randf_range(5.0, 11.0)
	data.t = randf()
	node.set_meta("carpath", data)
	return node

class CarPath:
	var route: PackedVector3Array = PackedVector3Array()
	var speed: float = 6.0
	var t: float = 0.0

func _process(delta: float) -> void:
	if _cars.is_empty():
		return
	for car in _cars:
		var data: CarPath = car.get_meta("carpath")
		var pts: PackedVector3Array = data.route
		if pts.size() < 2:
			continue
		var seg_count := pts.size() - 1
		data.t += delta * data.speed * _traffic_density / maxf(1.0, float(seg_count) * CityLayout.SPACING)
		if data.t >= 1.0:
			data.t -= 1.0
			# neue Route (Ziel zufällig) -> Stadt wirkt belebt statt Loop-Karussell
			data.route = CityLayout.route(car.global_position, CityLayout.node_pos(randi() % CityLayout.GRID, randi() % CityLayout.GRID) + Vector3(0, 1, 0))
		var f := data.t * float(seg_count)
		var i := int(f) % seg_count
		var frac := f - floorf(f)
		var p := pts[i].lerp(pts[min(i + 1, seg_count)], clampf(frac, 0.0, 1.0))
		var look: Vector3 = pts[min(i + 1, seg_count)]
		car.position = p + Vector3(0, 0.95, 0)
		if look.distance_squared_to(p) > 0.01:
			car.look_at(look + Vector3(0, 0.95, 0), Vector3.UP)

func _build_peds() -> void:
	var root := Node3D.new()
	root.name = "Pedestrians"
	(city_root if city_root != null else get_parent()).add_child(root)
	for i in PED_COUNT:
		var ped := NPCCarrier.new()
		ped.name = "Ped_%02d" % i
		ped.color_a = Color.from_hsv(randf(), 0.5, 0.8)
		ped.color_b = Color(0.2, 0.2, 0.28)
		ped.wander_center = CityLayout.node_pos(randi() % CityLayout.GRID, randi() % CityLayout.GRID)
		root.add_child(ped)
		_peds.append(ped)
