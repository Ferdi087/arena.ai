extends Resource
class_name EmployeeData
## NPC-Mitarbeiter – absichtlich nicht perfekt (#20/#21).

@export var id: StringName = &""
@export var first_name: String = "Bodo"
@export var traits: String = "singt beim Schleppen"
@export_group("Attributes (0..1)")
@export var speed: float = 0.5
@export var strength: float = 0.5
@export var accuracy: float = 0.5
@export var intelligence: float = 0.5
@export var reliability: float = 0.5 # niedrig -> lässt Möbel fallen / läuft gegen Türen
@export var stress_resistance: float = 0.5
@export var driving_skill: float = 0.5
@export var furniture_knowledge: float = 0.5
@export_group("Management")
@export var wage_per_hour: float = 12.0
@export var specialty: StringName = &"carry" # carry|sweep|drive|sort
@export var energy: float = 1.0 # 0..1, sinkt im Dienst
@export var morale: float = 0.7
@export var xp: float = 0.0

func drop_chance() -> float:
	## Basis-Fallwahrscheinlichkeit pro Trage-Aktion – der Humor-Hebel (#20).
	return clampf(0.30 * (1.0 - reliability) + 0.12 * (1.0 - accuracy), 0.02, 0.42)

func move_speed_multiplier() -> float:
	return lerpf(0.72, 1.18, speed)
