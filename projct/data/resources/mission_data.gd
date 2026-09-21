extends Resource
class_name MissionData
## Auftragsdefinition – Missions sind reine Daten, der Kerncode ändert sich nie (#42/#89/#128).

enum Difficulty { EASY, NORMAL, HARD, EXTREME }

@export var mission_id: StringName = &""
@export var display_name: String = ""
@export var client_name: String = ""
@export var client_type: StringName = &"student" # student|family|business|retiree|millionaire|musician|eccentric…
@export var description: String = ""
@export_group("Route")
@export var source_district: StringName = &"residential"
@export var destination_district: StringName = &"residential"
@export var source_building: String = "" # Label fürs UI
@export var dest_building: String = ""
@export_group("Content")
@export var furniture_manifest: Array[FurnitureData] = []
@export var special_rules: PackedStringArray = PackedStringArray() # "haunted", "crane", "aquarium_no_tilt", "weight_balancing", "messy_hoard", "high_wind"
@export_group("Economy & Time")
@export var difficulty: Difficulty = Difficulty.NORMAL
@export var base_payment: float = 2000.0
@export var time_limit_seconds: float = 900.0
@export var damage_multiplier: float = 1.0
@export var min_reputation: float = 0.0
@export var min_company_level: int = 0
@export_group("Atmosphere")
@export var weather_override: int = -1 # -1 = globales Wetter
@export var force_night: bool = false
@export var objectives: Array[ObjectiveData] = []

func total_item_value() -> float:
	var v := 0.0
	for f in furniture_manifest:
		v += f.item_value
	return v

func required_haulers() -> int:
	var r := 1
	for f in furniture_manifest:
		r = maxi(r, f.required_haulers)
	return r
