extends Resource
class_name MaterialDef
## Material-Definition – die gemeinsame Datenbasis für Damage, Audio, Reibung,
## Nässe und Paint (Master-Prompt #79/#80). Eine Instanz pro Materialtyp,
## referenziert von FurnitureData/VehicleData/BuildPieceData.

enum MaterialType { WOOD, METAL, GLASS, PLASTIC, FABRIC, CERAMIC, RUBBER, CONCRETE, ASPHALT, GRASS, WATER }

@export var id: StringName = &""
@export var display_name: String = ""
@export var material_type: MaterialType = MaterialType.WOOD
## Reibung (trocken) und Nässe-Multiplikator -> Rutsch-System #80
@export_group("Physics")
@export_range(0.01, 2.0, 0.01) var friction_dry: float = 0.8
@export_range(0.05, 1.0, 0.01) var friction_wet_multiplier: float = 0.6
@export_range(0.0, 1.0, 0.01) var restitution: float = 0.15
@export_range(0.0, 3.0, 0.01) var density: float = 0.8 # kg pro Liter-Volumen
## Schaden
@export_group("Damage")
@export_range(0.05, 8.0, 0.05) var damage_multiplier: float = 1.0 # empfindlich = hoch
@export_range(0.0, 50.0, 0.1) var min_impact_speed_for_damage: float = 2.2 # m/s – darunter nie Schaden (kein Pixel-Schaden)
@export var fracture_behavior: StringName = &"scratch" # scratch|dent|crack|shatter|bend
## Audio (Keys ins Content-Audio-Register)
@export_group("Audio")
@export var impact_sound_set: StringName = &"wood"
## Paint
@export_group("Paint")
@export var paintable: bool = true
@export var paint_absorbency: float = 1.0 # 1 = volle Deckkraft pro Strich

func wet_friction() -> float:
	return friction_dry * friction_wet_multiplier
