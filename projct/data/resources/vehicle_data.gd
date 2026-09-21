extends Resource
class_name VehicleData
## Fahrzeug-Definition inkl. fahrphysikalischer Kernparameter (#27/#29/#81).
## Der VehicleController liest NUR diese Werte – Tuning ohne Code-Änderung (#124).

@export var id: StringName = &""
@export var display_name: String = ""
@export var purchase_price: float = 0.0
@export var required_company_level: int = 0
@export_group("Mass & Body")
@export var chassis_mass_kg: float = 1800.0
@export var max_cargo_mass_kg: float = 1200.0
@export var body_half_extents: Vector3 = Vector3(1.05, 0.55, 2.2)
@export var cargo_area_size: Vector3 = Vector3(1.9, 1.6, 3.0) # Ladevolumen hinten
@export var cargo_area_offset: Vector3 = Vector3(0, 0.75, 1.9)
@export_group("Drive")
@export var engine_power_n: float = 9000.0 # Kraft an Antriebsachse bei 0 Tacho
@export var top_speed_kmh: float = 95.0
@export var reverse_speed_kmh: float = 30.0
@export var brake_power_n: float = 16000.0
@export var steering_max_deg: float = 38.0
@export var steering_speed: float = 4.5
@export_group("Suspension")
@export var wheel_radius: float = 0.42
@export var wheel_positions: Array[Vector3] = [
	Vector3(-0.95, -0.15, -1.45), Vector3(0.95, -0.15, -1.45),
	Vector3(-0.95, -0.15, 1.45), Vector3(0.95, -0.15, 1.45),
]
@export var suspension_length: float = 0.55
@export var suspension_stiffness: float = 55.0 # pro Rad, relativ zu Masse
@export var damping_ratio: float = 0.35
@export var anti_roll_stiffness: float = 1.2
@export_group("Grip")
@export var base_grip: float = 1.0 # wird mit MaterialDef/Regen multipliziert
@export_group("Visual (spätere Asset-Slots)")
@export var mesh_scene: PackedScene
@export var primary_color: Color = Color(0.85, 0.55, 0.12)
@export var secondary_color: Color = Color(0.2, 0.22, 0.26)
@export var horn_sound: StringName = &"horn_truck"
