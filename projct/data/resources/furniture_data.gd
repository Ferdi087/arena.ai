extends Resource
class_name FurnitureData
## Datendefinition eines Möbelstücks – alles statische, keine Laufzeitobjekte (#37).

enum SizeClass { TINY, SMALL, MEDIUM, LARGE, XLARGE, HUGE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var category: StringName = &"generic" # seating|storage|appliance|electronics|decor|special
@export var material: MaterialDef
@export_group("Physics")
@export var mass_kg: float = 25.0
@export var size_class: SizeClass = SizeClass.MEDIUM
@export var half_extents: Vector3 = Vector3(0.4, 0.4, 0.4) # Kollisionsbox; Komplexes -> CollisionScene
@export var center_of_mass_offset: Vector3 = Vector3.ZERO # realer Schwerpunkt (Klavier vorn schwer …)
@export_range(1, 4) var required_haulers: int = 1 # Co-Lift-Anforderung #33
@export_group("Value")
@export var purchase_price: float = 100.0
@export var item_value: float = 100.0 # Basis für Schadensabzug bei Auszahlung
@export_range(0.0, 5.0, 0.05) var fragility: float = 1.0 # skaliert DamageSettings
@export var rarity: int = 0 # 0 common .. 4 legendary (Sandbox/Catalog)
@export_group("Visual (Asset-Slot für spätere .glb – leer = prozedural)")
@export var mesh_scene: PackedScene
@export var base_color: Color = Color(0.65, 0.45, 0.3)
@export var accent_color: Color = Color(0.3, 0.3, 0.35)
@export var breakable_glass_area: float = 0.0 # 0..1 Anteil Glasflächen (Splitter-Verhalten)

static func size_label(sc: SizeClass) -> String:
	match sc:
		SizeClass.TINY: return "Kleinst"
		SizeClass.SMALL: return "Klein"
		SizeClass.MEDIUM: return "Mittel"
		SizeClass.LARGE: return "Groß"
		SizeClass.XLARGE: return "Sehr groß"
		SizeClass.HUGE: return "Monströs"
	return "?"
