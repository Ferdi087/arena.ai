extends BaseScreen
class_name ExtrasScreen
## Freischaltbares: Hupen-Sammlung, Musik-Player (Dev-Ton), Debug-Schalter,
## Erfolgs-/Sammlerliste. Alles wirkt real (unlock_changed-Flags aus Company).

func _ready() -> void:
	title = "EXTRAS & SECRETS"
	overlay_enum = UI.Overlay.EXTRAS
	super()

func _panel_size() -> Vector2:
	return Vector2(720, 560)

func build_body(body: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	v.add_child(_h("", "HUPEN & SPASS"))
	for u in Content.upgrades.values():
		if u.category != UpgradeData.Category.HORN:
			continue
		var installed := false
		for vid_s in Company.data.owned_vehicles:
			if Company.upgrades_for(StringName(vid_s)).has(String(u.id)):
				installed = true
		var b := Button.new()
		b.text = "%s – %s" % [u.display_name, "✓ montiert, H-Taste" if installed else ("Level %d nötig" % u.required_company_level if int(Company.data.company_level) < u.required_company_level else "im Truck-Shop montierbar")]
		b.disabled = true
		v.add_child(b)
	v.add_child(_h("", "SAMMLUNG (Geheimnisse & Kuriositäten)"))
	var flags := {&"golden_toilet": "Goldene Toilette gestohlen? :)", &"cat_bell": "Die Katze mag dich", &"haunted_survivor": "Nacht im Spukhaus überlebt", &"rival_busted": "Konkurrenz floppt"}
	for f in flags:
		var l := _h("", "")
		l.text = ("★ " if Company.has_unlock(f) else "☆ ") + String(flags[f])
		v.add_child(l)
	v.add_child(_h("", "DEV / SPASS-SCHALTER"))
	var t1 := CheckBox.new()
	t1.text = "Schadens-Popups an"
	t1.button_pressed = Settings.damage_popups
	t1.toggled.connect(func(on: bool): Settings.damage_popups = on)
	v.add_child(t1)
	var t2 := CheckBox.new()
	t2.text = "Regen erzwingen (Welt antesten)"
	t2.toggled.connect(func(on: bool):
		var wx := _weather()
		if wx != null:
			if on:
				wx.force_set(WeatherController.Kind.RAIN)
			else:
				wx.unforce())
	v.add_child(t2)
	var t3 := CheckBox.new()
	t3.text = "Nacht erzwingen (23:30)"
	t3.toggled.connect(func(on: bool):
		var w := get_tree().get_first_node_in_group("world")
		if w != null and w.day_night != null:
			w.day_night.set_hour(23.5 if on else 9.0))
	v.add_child(t3)

func _weather():
	var w := get_tree().get_first_node_in_group("world")
	if w != null:
		return w.get("weather")
	return null

func _h(_p: String, text: String) -> Label:
	var l := Label.new()
	l.text = "[ %s ]" % text
	l.add_theme_font_size_override("font_size", 20)
	l.modulate = Color(0.9, 0.75, 0.4)
	return l
