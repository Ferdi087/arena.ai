extends BaseScreen
class_name GarageScreen
## Garage: Fuhrpark verwalten + Upgrades kaufen (#16/#18 – Werkstatt-Terminal).

func _ready() -> void:
	title = "GARAGE"
	overlay_enum = UI.Overlay.GARAGE
	super()

func _panel_size() -> Vector2:
	return Vector2(900, 620)

func build_body(body: Control) -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(360, 0)
	row.add_child(list)
	var head := Label.new()
	head.text = "Fuhrpark (%.0f €)" % Company.money
	head.add_theme_font_size_override("font_size", 20)
	list.add_child(head)
	for vid_s in Company.data.owned_vehicles:
		var vid := StringName(vid_s)
		var v := Content.get_vehicle(vid)
		if v == null:
			continue
		var eff := Company.effective_vehicle_data(vid)
		var b := Button.new()
		var ups := Company.upgrades_for(vid)
		b.text = "%s\n%d Stück · Ladevolumen %.1f t · %s" % [
			v.display_name, maxi(1, eff.cargo_area_size.length()), eff.cargo_area_size.x * eff.cargo_area_size.y * eff.cargo_area_size.z / 4.0,
			", ".join(Array(ups)) if ups.size() > 0 else "keine Upgrades"]
		b.pressed.connect(_show_upgrades.bind(vid))
		list.add_child(b)
	if Company.data.owned_vehicles.is_empty():
		var none := Label.new()
		none.text = "Kein Fahrzeug! Erst im Fahrzeug-Shop kaufen."
		list.add_child(none)
	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_upgrades_host = VBoxContainer.new()
	right.add_child(_upgrades_host)

var _upgrades_host: VBoxContainer

func _show_upgrades(vid: StringName) -> Callable:
	return func() -> void:
		for c in _upgrades_host.get_children():
			c.queue_free()
		var head := Label.new()
		head.text = "Upgrades – %s" % String(vid)
		_upgrades_host.add_child(head)
		for up in Content.upgrades.values():
			if up.category == UpgradeData.Category.TOOL:
				continue
			var owned := Company.upgrades_for(vid).has(String(up.id))
			var lvl_ok := int(Company.data.company_level) >= up.required_company_level
			var btn := Button.new()
			var mods := PackedStringArray()
			for k in up.modifiers.keys():
				mods.append("%s %s" % [String(k), String(up.modifiers[k])])
			var state := "✓ installiert" if owned else ("%.0f €" % up.cost if lvl_ok else "Level %d nötig" % up.required_company_level)
			btn.text = "%s – %s\n%s" % [up.display_name, state, ", ".join(mods)]
			btn.disabled = owned or not lvl_ok
			btn.pressed.connect(func() -> void:
				if Company.buy_upgrade(vid, up):
					Sfx.ui_confirm()
					UI.toast("%s montiert!" % up.display_name)
					_show_upgrades(vid).call()
				else:
					Sfx.ui_click()
					UI.toast("Zu wenig Geld oder Level zu niedrig."))
			_upgrades_host.add_child(btn)
		if not _upgrades_host.get_child_count() > 1:
			var none := Label.new()
			none.text = "Keine Truck-Upgrades im Katalog."
			_upgrades_host.add_child(none)
