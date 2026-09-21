extends Resource
class_name UpgradeData
## Garage/Shop-Upgrades – datengetrieben, wirkt auf VehicleData/Company (#28).

enum Category { ENGINE, SUSPENSION, WHEELS, CARGO_AREA, LIGHTS, PAINT, HORN, COMPANY, TOOL }

@export var id: StringName = &""
@export var display_name: String = ""
@export var category: Category = Category.ENGINE
@export var cost: float = 500.0
@export var required_company_level: int = 0
@export var required_reputation: float = 0.0
## Modifikatoren: Pfad -> Multiplikator/Additiv, z. B. "engine_power_n": {"mult":1.35}
@export var modifiers: Dictionary = {}
@export var tags: PackedStringArray = PackedStringArray()
