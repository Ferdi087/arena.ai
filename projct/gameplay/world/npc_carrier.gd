extends Node3D
class_name NPCCarrier
## Einfacher Fußgänger: Prozedural-Kapsel-Mensch mit Wackelgang, Tagesplan
## (Nachts weniger/mehr Ampel-Jogger), Zielwechsel. SIM-Stufen über ChunkManager
## (set_physics_process / visible). Kein NavigationMesh nötig im Slice:
## direkte wander-Steuerung mit Kollisionsskips. (#23/#77)

@export var walk_speed: float = 1.35
var color_a := Color(0.8, 0.3, 0.3)
var color_b := Color(0.2, 0.25, 0.35)
var wander_center := Vector3.ZERO

var _target := Vector3.ZERO
var _bob: float = 0.0
var _wait: float = 0.0
var _torso: MeshInstance3D = null
var _head: MeshInstance3D = null
var _legL: MeshInstance3D = null
var _legR: MeshInstance3D = null

func _ready() -> void:
	add_to_group("npcs")
	var style := get_node_or_null(^"/root/Style") as StyleService
	var mat_a: StandardMaterial3D = style.get_flat_material(&"ped_shirt", color_a) if style != null else _fb(color_a)
	var mat_b: StandardMaterial3D = style.get_flat_material(&"ped_pants", color_b) if style != null else _fb(color_b)
	_torso = _part(Vector3(0.34, 0.5, 0.22), Vector3(0, 1.05, 0), mat_a)
	_head = _part(Vector3(0.26, 0.26, 0.26), Vector3(0, 1.46, 0), _fb(Color(0.95, 0.75, 0.6)))
	_legL = _part(Vector3(0.12, 0.6, 0.12), Vector3(-0.09, 0.42, 0), mat_b)
	_legR = _part(Vector3(0.12, 0.6, 0.12), Vector3(0.09, 0.42, 0), mat_b)
	_pick_target()

func _fb(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

func _part(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi

func _pick_target() -> void:
	var around := CityLayout.node_pos(randi() % CityLayout.GRID, randi() % CityLayout.GRID)
	_target = around + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))

func _physics_process(delta: float) -> void:
	var flat := Vector3(global_position.x, 0, global_position.z)
	var to := Vector3(_target.x, 0, _target.z) - flat
	to.y = 0
	if to.length() < 1.2:
		_wait -= delta
		if _wait <= 0.0:
			_pick_target()
			_wait = randf_range(1.0, 4.0)
		return
	to = to.normalized()
	var speed := walk_speed * (1.7 if WeatherAccess.is_night() else 1.0)
	global_position += to * speed * delta
	global_position.y = 0.0
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(8.0 * delta, 0.0, 1.0))
	_bob += delta * (6.0 + speed * 2.0)
	var swing := sin(_bob) * 0.5
	if _legL != null:
		_legL.rotation.x = swing
	if _legR != null:
		_legR.rotation.x = -swing
	if _torso != null:
		_torso.rotation.z = sin(_bob * 0.5) * 0.06
		_torso.position.y = 1.05 + absf(sin(_bob)) * 0.02
