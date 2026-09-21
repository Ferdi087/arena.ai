extends Resource
class_name PayoutResult
## Berechnetes Auszahlungsergebnis – zentral konfigurierbare Formel (#41),
## errechnet von PayoutCalculator aus DamageSettings + MissionData.

@export var base_payment: float = 0.0
@export var damage_penalty: float = 0.0   # negativ
@export var time_bonus: float = 0.0
@export var objective_bonus: float = 0.0
@export var reputation_delta: float = 0.0
@export var final_amount: float = 0.0
@export var grade: StringName = &"ok" # flawless|good|ok|poor|failed
@export var breakdown_lines: PackedStringArray = PackedStringArray()

func to_display() -> String:
	var text := "Basis: %.0f €\n" % base_payment
	for line in breakdown_lines:
		text += line + "\n"
	text += "SUMME: %.0f €   [%s]" % [final_amount, String(grade).to_upper()]
	return text
