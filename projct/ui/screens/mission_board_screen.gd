extends BaseScreen
class_name MissionBoardScreen
## Der Firmen-Computer: Auftragsannahme, Marketing, Mitarbeiter, Website,
## Statistiken – Tabs statt Sub-Szenen-Gefrickel (#17).

func _ready() -> void:
	title = "FIRMENPORTAL – %s" % Company.data.company_name
	overlay_enum = UI.Overlay.MISSION_BOARD
	super()

func _panel_size() -> Vector2:
	return Vector2(940, 640)

func build_body(body: Control) -> void:
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	tabs.add_child(_jobs_tab())
	tabs.add_child(_marketing_tab())
	tabs.add_child(_staff_tab())
	tabs.add_child(_website_tab())
	tabs.add_child(_stats_tab())

func _mk(name_s: String) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.name = name_s
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(v)
	return s

func _jobs_tab() -> ScrollContainer:
	var scroll := _mk("Aufträge")
	var v := scroll.get_child(0)
	var hint := Label.new()
	hint.text = "Angenommene Aufträge erscheinen auf der Karte (M). Ziel: erst beladen, dann in die Zielzone liefern."
	v.add_child(hint)
	if Missions.has_active_mission():
		var cur := Button.new()
		var m := Missions.active_mission
		cur.text = "AKTUELL: %s · %.0f € · Abbrechen (-250 €)" % [m.display_name, m.base_payment]
		cur.pressed.connect(func() -> void:
			Missions.abandon()
			_rebuild())
		v.add_child(cur)
	for m in Missions.offered:
		var b := Button.new()
		var lines := PackedStringArray()
		for f in m.furniture_manifest:
			lines.append(f.display_name)
		b.text = "%s\nKunde: %s · %d Stück · Zahlung: %.0f € · Zeit: %ds%s" % [
			m.display_name, m.client_name, m.furniture_manifest.size(), m.base_payment,
			int(m.time_limit_seconds),
			"  [SPEZIAL: %s]" % ", ".join(PackedStringArray(m.special_rules)) if m.special_rules.size() > 0 else "",
		]
		if Missions.has_active_mission():
			b.disabled = true
		b.pressed.connect(func() -> void:
			if Missions.accept(m):
				Sfx.ui_confirm()
				UI.toast("Auftrag angenommen: %s" % m.display_name)
				_rebuild())
		v.add_child(b)
	if Missions.offered.is_empty():
		var none := Label.new()
		none.text = "Keine Angebote – Marketing rauf oder warten…"
		v.add_child(none)
	return scroll

func _marketing_tab() -> ScrollContainer:
	var scroll := _mk("Marketing")
	var v := scroll.get_child(0)
	var t := Label.new()
	t.text = "Mehr Werbung = mehr Aufträge, aber auch mehr Stress & Anspruch."
	v.add_child(t)
	var names := ["Keine", "Plakate & Flyer", "Social Media", "Radio-Spot", "Premium-Kampagne", "AGGRESSIVE OFFENSIVE"]
	for i in names.size():
		var b := Button.new()
		var cost := Content.economy_settings.marketing_costs[i]
		b.text = "%s – %.0f €" % [names[i], cost]
		if Company.data.marketing_tier == i:
			b.disabled = true
			b.text += "  (aktiv)"
		var idx := i
		b.pressed.connect(func() -> void:
			Company.set_marketing_tier(idx)
			_rebuild())
		v.add_child(b)
	return scroll

func _staff_tab() -> ScrollContainer:
	var scroll := _mk("Personal")
	var v := scroll.get_child(0)
	for e in Company.employees:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s (%s) · %.0f €/h · Zuverlässl. %d%%" % [e.first_name, String(e.specialty), e.wage_per_hour, int(e.reliability * 100)]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var fire := Button.new()
		fire.text = "Firen"
		var idx := Company.employees.find(e)
		fire.pressed.connect(func() -> void:
			Company.fire(idx)
			_rebuild())
		row.add_child(fire)
		v.add_child(row)
	if Company.employees.is_empty():
		var none := Label.new()
		none.text = "Kein Personal. Hiring-Desk im HQ (oder 'Einstellungen' – Slice-Hinweis)."
		v.add_child(none)
	return scroll

func _website_tab() -> ScrollContainer:
	var scroll := _mk("Website")
	var v := scroll.get_child(0)
	var head := Label.new()
	head.text = "Firmenwebsite – Kunden sehen das hier:"
	v.add_child(head)
	var pv := PanelContainer.new()
	var pvv := VBoxContainer.new()
	pv.add_child(pvv)
	var name_l := Label.new()
	name_l.text = Company.data.company_name
	name_l.add_theme_font_size_override("font_size", 26)
	pvv.add_child(name_l)
	var slogan_l := Label.new()
	slogan_l.text = "„%s“" % Company.data.slogan
	pvv.add_child(slogan_l)
	var about_l := Label.new()
	about_l.text = Company.data.website_about_text if not Company.data.website_about_text.is_empty() else "(Noch kein Über-uns-Text.)"
	about_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pvv.add_child(about_l)
	var logo := TextureRect.new()
	logo.texture = Company.logo_image(128)
	logo.custom_minimum_size = Vector2(128, 128)
	pvv.add_child(logo)
	v.add_child(pv)
	var name_edit := LineEdit.new()
	name_edit.text = Company.data.company_name
	name_edit.placeholder_text = "Firmenname"
	v.add_child(name_edit)
	var slogan_edit := LineEdit.new()
	slogan_edit.text = Company.data.slogan
	slogan_edit.placeholder_text = "Slogan"
	v.add_child(slogan_edit)
	var about_edit := LineEdit.new()
	about_edit.text = Company.data.website_about_text
	about_edit.placeholder_text = "Über uns (ein Satz)"
	v.add_child(about_edit)
	var theme_opt := OptionButton.new()
	for t in ["budget", "clean", "flashy", "luxury"]:
		theme_opt.add_item(String(t))
	v.add_child(theme_opt)
	var apply_b := Button.new()
	apply_b.text = "Website aktualisieren"
	apply_b.pressed.connect(func() -> void:
		var theme_name: StringName = StringName(theme_opt.get_item_text(theme_opt.selected)) if theme_opt.selected >= 0 else &"budget"
		Company.set_website(name_edit.text, theme_name, Company.data.brand_color, slogan_edit.text, about_edit.text)
		UI.toast("Website live! Kunden reagieren.")
		Sfx.ui_confirm()
		_rebuild())
	v.add_child(apply_b)
	return scroll

func _stats_tab() -> ScrollContainer:
	var scroll := _mk("Statistik")
	var v := scroll.get_child(0)
	var txt := RichTextLabel.new()
	txt.bbcode_enabled = true
	txt.fit_content = true
	txt.custom_minimum_size = Vector2(880, 420)
	var jobs_done := int(Company.data.stats.get("jobs_done", 0))
	var money_earned := float(Company.data.stats.get("money_earned", 0.0))
	var damage_total := float(Company.data.stats.get("damage_total", 0.0))
	var lines := "[b]UNTERNEHMENSPROFIL[/b]\nName: %s\nLevel: %d (XP %.0f)\nKontostand: %.0f €\nGesamt verdient: %.0f €\nReputation: %.0f\nAufträge erledigt: %d\nAnzahl Jobs in Historie: %d\nMitarbeiter: %d\nFuhrpark: %s\nMöbel im Katalog: %d\nHQ-Qualität: %.0f" % [
		Company.data.company_name, Company.company_level, Company.xp, Company.money,
		money_earned, Company.reputation, jobs_done, Missions.history.size(),
		Company.employees.size(), ", ".join(Array(Company.data.owned_vehicles)),
		Company.data.collected_catalog.size(), _hq_quality()]
	txt.text = lines
	v.add_child(txt)
	return scroll

func _hq_quality() -> float:
	var w := get_tree().get_first_node_in_group("world")
	if w != null and w is HQRoot and (w as HQRoot).build_mode != null:
		return (w as HQRoot).build_mode.quality_score()
	return 0.0

func _rebuild() -> void:
	# Panel neu aufbauen: billig & frisch.
	var panel := get_node_or_null("Panel")
	if panel != null:
		panel.queue_free()
	# Einfach overlay neu öffnen (close/open Zyklus).
	UI.close(UI.Overlay.MISSION_BOARD)
	UI.open(UI.Overlay.MISSION_BOARD)
