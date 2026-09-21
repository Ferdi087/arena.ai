extends Node3D
class_name VehicleWheel
## Rad-Visual + Feedback (Federweg, Lenkwinkel, Spin). KEINE eigene Physik –
## die Kräfte berechnet VehicleController._integrate_forces (eine Quelle).

var index: int = 0
var _mesh: MeshInstance3D
var _tire_r: float = 0.42
var _spin: float = 0.0
var _steer_angle: float = 0.0
var _compress_vis: float = 0.0

func _ready() -> void:
	var style := get_node_or_null(^"/root/Style") as StyleService
	_mesh = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = _tire_r
	cm.bottom_radius = _tire_r
	cm.height = 0.24
	cm.top_radius *= 0.98
	_mesh.mesh = cm
	if style != null:
		_mesh.material_override = style.get_flat_material(&"tire", Color(0.12, 0.12, 0.13), 0.92)
		# Radnabe als zweites Mesh
		var hub := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = _tire_r * 0.45
		hm.bottom_radius = hm.top_radius
		hm.height = 0.26
		hub.mesh = hm
		hub.material_override = style.get_flat_material(&"rim", Color(0.75, 0.76, 0.8), 0.3, 0.7)
		add_child(hub)
	add_child(_mesh)
	_mesh.rotation.z = PI / 2.0
	set_physics_process(true)

func update_visual(compression: float, steer: float, spin_speed: float, grounded: bool) -> void:
	_compress_vis = lerpf(_compress_vis, clampf(compression, 0.0, 1.0), 0.5)
	_steer_angle = steer
	position.y = -_compress_vis * 0.14
	_spin += spin_speed * (1.0 / 60.0)
	if not grounded:
		_spin += 0.02
	if _mesh != null:
		_mesh.rotation.x = _spin
		rotation.y = _steer_angle
