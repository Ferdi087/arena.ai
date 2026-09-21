extends Resource
class_name ObjectiveData
## Ein Auftragziel – datengetrieben, von MissionRuntime ausgewertet (#94).
##
## Typen (StringName):
##  "move_items"   – N Möbel von Zone A nach Zone B (payload: count, source_tag, dest_tag)
##  "no_damage_on" – bestimmtes FurnitureData-id darf < Schwelle bleiben
##  "time_limit"   – Deadline (Sekunden ab Start)
##  "load_vehicle" – X kg bzw. N Items im Truck-Volume
##  "deliver"      – Truck mit Zielinhalt in Zielzone
##  "custom"       – Hook für Special-Rules-Systeme (#128)

@export var id: StringName = &""
@export var description: String = ""
@export var type: StringName = &"move_items"
@export var required_count: int = 1
@export var optional: bool = false # Bonusziel
@export var bonus_money: float = 0.0
@export var params: Dictionary = {} # typspezifisch, z. B. {"max_damage":20,"furniture_id":&"piano"}
