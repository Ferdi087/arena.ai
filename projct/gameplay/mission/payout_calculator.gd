extends RefCounted
class_name PayoutCalculator
## Die EINZIGE Stelle, an der Bezahlung berechnet wird (#41/#115).
## Rein funktional => deterministisch testbar (tests/test_payout.gd).

static func calculate(mission: MissionData, damage_by_item: Dictionary, elapsed_seconds: float,
		objectives_done: Array[StringName], objectives_optional_done: Array[StringName],
		destroyed_items: Array[StringName]) -> PayoutResult:
	var s: DamageSettings = Content.damage_settings
	var res := PayoutResult.new()
	res.base_payment = mission.base_payment
	var lines := PackedStringArray()

	# 1) Schadensabzug pro Item
	var total_damage_penalty := 0.0
	var total_damage_points := 0.0
	var item_count := maxi(mission.furniture_manifest.size(), 1)
	for fid_str in damage_by_item:
		var dmg: float = float(damage_by_item[fid_str])
		total_damage_points += dmg / float(item_count)
		var f: FurnitureData = Content.get_furniture(StringName(String(fid_str)))
		var value: float = f.item_value if f != null else 100.0
		total_damage_penalty -= value * dmg / 100.0 * s.damage_penalty_per_percent * 100.0
	for did in destroyed_items:
		var f2: FurnitureData = Content.get_furniture(did)
		if f2 != null:
			total_damage_penalty -= f2.item_value * (s.destroyed_item_penalty_mult - 1.0)
	total_damage_penalty = clampf(total_damage_penalty, -mission.base_payment * 1.4, 0.0)
	if total_damage_penalty < -1.0:
		lines.append("Schäden: %.0f €" % total_damage_penalty)
	res.damage_penalty = total_damage_penalty

	var missed_penalty := 0.0
	# 2) Zeitbonus/-strafe
	var time_left_ratio := 1.0 - clampf(elapsed_seconds / maxf(mission.time_limit_seconds, 1.0), 0.0, 2.0)
	var time_bonus := mission.base_payment * s.time_bonus_full * clampf(time_left_ratio, 0.0, 1.0)
	if elapsed_seconds > mission.time_limit_seconds:
		var overdue_min := (elapsed_seconds - mission.time_limit_seconds) / 60.0
		var penalty := mission.base_payment * s.time_penalty_per_overdue_minute * overdue_min
		time_bonus = -minf(penalty, mission.base_payment * 0.6)
	if absf(time_bonus) > 1.0:
		lines.append("Zeit: %s%.0f €" % ["+" if time_bonus > 0.0 else "", time_bonus])
	res.time_bonus = time_bonus

	# 3) Objectives
	var obj_bonus := 0.0
	for o in mission.objectives:
		if o.type == &"time_limit":
			continue
		if o.optional:
			if o.id in objectives_optional_done:
				obj_bonus += o.bonus_money
		elif o.id in objectives_done:
			obj_bonus += o.bonus_money
		elif not o.optional:
			# Pflichtziel verfehlt => Teilerfolg, Abzug
			missed_penalty -= mission.base_payment * 0.1
	if absf(obj_bonus) > 0.5:
		lines.append("Bonus-Ziele: +%.0f €" % obj_bonus)
	if missed_penalty < -1.0:
		lines.append("Pflichtziele offen: %.0f €" % missed_penalty)
	res.objective_bonus = obj_bonus

	# 4) Grad + Reputation
	var avg_damage := clampf(total_damage_points, 0.0, 100.0)
	var destroyed_any := not destroyed_items.is_empty()
	var grade := &"ok"
	var rep := s.normal_reputation_gain
	if avg_damage < 1.0 and destroyed_items.is_empty() and elapsed_seconds <= mission.time_limit_seconds:
		grade = &"flawless"
		obj_bonus += mission.base_payment * s.flawless_bonus
		rep = s.flawless_reputation_gain
		lines.append("PERFEKT +%.0f €" % (mission.base_payment * s.flawless_bonus))
	elif avg_damage < 20.0:
		grade = &"good"
		rep = s.normal_reputation_gain * 1.2
	elif avg_damage > 55.0 or destroyed_any:
		grade = &"poor"
		rep = -1.0
	if not destroyed_items.is_empty():
		rep -= 1.5 * float(destroyed_items.size())
	res.grade = grade
	res.reputation_delta = clampf(rep, -10.0, 10.0)

	var final_amt := mission.base_payment + res.damage_penalty + res.time_bonus + obj_bonus + missed_penalty
	# Minimum: 5% Behaltens-Regel, sonst ist alles Frust
	final_amt = maxf(final_amt, mission.base_payment * 0.05)
	res.final_amount = snappedf(final_amt, 1.0)
	res.breakdown_lines = lines
	return res

static func failed_result(mission: MissionData, reason: StringName) -> PayoutResult:
	var s: DamageSettings = Content.damage_settings
	var res := PayoutResult.new()
	res.base_payment = 0.0
	res.final_amount = 0.0
	res.grade = &"failed"
	res.reputation_delta = -s.fail_reputation_loss
	res.breakdown_lines = PackedStringArray(["Abbruch/gescheitert (%s)" % String(reason)])
	return res
