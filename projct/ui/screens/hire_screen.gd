extends BaseScreen
class_name HireScreen
## Hiring-Desk im HQ: 3 Bewerber, Stats-Balken, Annehmen/Verwerfen.
## Bewerber-Pool lebt in Company (refresh_candidates), damit Save/Load
## denselben Markt zeigt. Kosten: eine Handlohn-Pauschale upfront.

func _ready() -> void:
	title = "BEWERBUNGSGESPRÄCH"
	overlay_enum = UI.Overlay.HIRE
	super()
	if Company.candidates.is_empty():
		Company.refresh_candidates(int(Time.get_unix_time_from_system() / 86400.0))

func _panel_size() -> Vector2:
	return Vector2(880, 540)

func build_body(body: Control) -> void:
	var head := Label.new()
	head.text = "Konto: %.0f € · Einstellung kostet eine Woche Vorschuss (Wochenlohn)." % Company.money
	body.add_child(head)
	for i in Company.candidates.size():
		var e := Company.candidates[i]
		var card := PanelContainer.new()
		var row := HBoxContainer.new()
		card.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var name_l := Label.new()
		name_l.text = "%s  ·  Spezialgebiet: %s  ·  „%s“" % [e.first_name, String(e.specialty), e.traits]
		col.add_child(name_l)
		var bars := GridContainer.new()
		bars.columns = 2
		col.add_child(bars)
		_bar(bars, "Tempo", e.speed)
		_bar(bars, "Kraft", e.strength)
		_bar(bars, "Geschick", e.accuracy)
		_bar(bars, "Zuverlässigkeit", e.reliability)
		_bar(bars, "Fahrkunst", e.driving_skill)
		_bar(bars, "Möbelkunde", e.furniture_knowledge)
		var wage_l := Label.new()
		wage_l.text = "%.1f €/h" % e.wage_per_hour
		wage_l.custom_minimum_size = Vector2(90, 0)
		row.add_child(wage_l)
		var btns := VBoxContainer.new()
		row.add_child(btns)
		var take := Button.new()
		take.text = "EINSTELLEN"
		var idx := i
		take.pressed.connect(_hire_idx.bind(idx))
		btns.add_child(take)
		var pass_b := Button.new()
		pass_b.text = "Ablehnen"
		pass_b.pressed.connect(func() -> void:
			Company.candidates.remove_at(idx)
			_rebuild())
		btns.add_child(pass_b)
		body.add_child(card)
	if Company.candidates.is_empty():
		var done := Label.new()
		done.text = "Keine Bewerber mehr – morgen früh (neuer Spieltag) stehen neue am Desk."
		body.add_child(done)
	var reroll := Button.new()
	reroll.text = "Bewerber-Liste auffrischen (50 €)"
	reroll.pressed.connect(_reroll)
	body.add_child(reroll)

func _reroll() -> void:
	if Company.try_spend(50.0, "Inserat"):
		Company.refresh_candidates(int(Time.get_unix_time_from_system()) + randi())
		_rebuild()
		UI.toast("Neue Inserate raus – neue Bewerber!")
	else:
		UI.toast("Das Inserat können wir uns nicht leisten.")

func _hire_idx(idx: int) -> void:
	if Company.hire_candidate(idx):
		Sfx.ui_confirm()
		UI.toast("Neue Kraft ist ab jetzt im Team!")
		_rebuild()
	else:
		UI.toast("Zu wenig Geld für den Vorschuss.")

func _bar(parent: Control, label: String, v01: float) -> void:
	var l := Label.new()
	l.text = "  %s" % label
	l.custom_minimum_size = Vector2(150, 0)
	parent.add_child(l)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = v01
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(180, 18)
	parent.add_child(bar)

func _rebuild() -> void:
	UI.close(UI.Overlay.HIRE)
	UI.open(UI.Overlay.HIRE)
