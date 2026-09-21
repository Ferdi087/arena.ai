extends Resource
class_name DamageSettings
## Zentrales Damage-Balancing (#69/#124): Der Damage-Service rechnet NUR mit
## diesen Werten – keine magischen Konstanten im Code.

@export_group("Impact Model")
@export var reference_impulse_velocity: float = 4.0 # m/s bei der 'base' rechnet
@export var damage_per_impulse_unit: float = 0.09 # % Schaden pro (Impulse/(mass*refV)) -Punkt
@export var min_impact_speed: float = 1.6 # m/s – unter dieser Relativgeschwindgk. nie Schaden
@export var crush_damage_mult: float = 1.6 # gequetscht (zwei Kontaktpunkte kurze Zeit)
@export var tumble_damage_per_90deg: float = 3.5 # Kippen/Hängen über Kante
@export var max_single_hit_damage: float = 45.0 # Anti-Spike-Kappe pro Event (Physik-Glitches)

@export_group("Grading (Prozent)")
@export_range(0.0, 100.0) var grade_scratch_end: float = 20.0
@export_range(0.0, 100.0) var grade_visible_end: float = 40.0
@export_range(0.0, 100.0) var grade_heavy_end: float = 70.0
@export_range(0.0, 100.0) var grade_critical_end: float = 99.0

@export_group("Payout (#41)")
@export var damage_penalty_per_percent: float = 0.006 # Anteil vom ItemValue je %-Punkt
@export var time_bonus_full: float = 0.15 # +15% wenn deutlich unter Zeitlimit
@export var time_penalty_per_overdue_minute: float = 0.04
@export var destroyed_item_penalty_mult: float = 1.5 # vs. Basiswert
@export var flawless_bonus: float = 0.10
@export var fail_reputation_loss: float = 4.0
@export var flawless_reputation_gain: float = 3.0
@export var normal_reputation_gain: float = 1.5

func grade_for(damage_percent: float) -> StringName:
	if damage_percent <= 0.5:
		return &"flawless"
	if damage_percent < grade_scratch_end:
		return &"light"
	if damage_percent < grade_visible_end:
		return &"visible"
	if damage_percent < grade_heavy_end:
		return &"heavy"
	if damage_percent < grade_critical_end:
		return &"critical"
	return &"destroyed"
