extends Resource
class_name CompanyData
## Firma – Persistenz-Daten des Company-Services (#13/#17/#18/#51).

@export var company_name: String = "Möbel-Rambo GmbH"
@export var slogan: String = "Wir schleppen, bis es kracht."
@export var logo_seed: int = 1337
@export var brand_color: Color = Color(0.95, 0.6, 0.1)
@export var website_theme: StringName = &"budget" # budget|clean|flashy|luxury
@export var website_about_text: String = ""
@export_group("Progression")
@export var money: float = 1500.0
@export var reputation: float = 10.0
@export var company_level: int = 1
@export var xp: float = 0.0
@export_group("Marketing")
@export var marketing_tier: int = 0 # 0..5
@export_group("Collections")
@export var unlocked_flags: PackedStringArray = PackedStringArray() # Achievements/Secrets
@export var purchased_cosmetics: PackedStringArray = PackedStringArray()
@export var collected_catalog: PackedStringArray = PackedStringArray() # Möbelkatalog #125
@export var owned_vehicles: PackedStringArray = PackedStringArray()
@export_group("Stats")
@export var stats: Dictionary = {} # jobs_done, damage_total, money_earned, best_streak…
