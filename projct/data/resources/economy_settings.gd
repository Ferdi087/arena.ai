extends Resource
class_name EconomySettings
## Zentrale Wirtschafts-Parameter (#19/#51/#96) – vom CompanyService verwendet.

@export_group("Level Curve")
@export var xp_per_job_normal: float = 100.0
@export var level_base_xp: float = 300.0
@export var level_xp_growth: float = 1.55 # exponentielle Kurve

@export_group("Reputation")
@export var rep_min: float = 0.0
@export var rep_max: float = 100.0
@export var rep_from_hq_quality_factor: float = 0.25 # #16: HQ-Qualität => Rep-Drift

@export_group("Marketing")
@export var marketing_costs: PackedFloat32Array = PackedFloat32Array([0, 150, 400, 900, 2000, 4500])
@export var marketing_demand_factor: PackedFloat32Array = PackedFloat32Array([0.35, 0.6, 1.0, 1.55, 2.2, 3.0])
@export var marketing_quality_factor: PackedFloat32Array = PackedFloat32Array([1.0, 1.02, 1.06, 1.12, 1.05, 0.92]) # aggressive Werbung nervt >4
@export var job_refresh_base_seconds: float = 90.0

@export_group("Wages / Bills")
@export var employee_upkeep_multiplier: float = 6.0 # Gehalt pro Job-Tick
@export var hq_rent_per_day: float = 120.0
