extends BaseScreen
class_name VehicleShopScreen
## Fahrzeug-Shop: Fuhrpark erweitern. Freischaltung über Firmenlevel
## (Content.required_level) + Geld. Kauf = sofort im Garage-Parkplatz.

func _ready() -> void:
	title = "FAHRZEUG-HÄNDLER"
	overlay_enum = UI.Overlay.SHOP_VEHICLE
	super()

func _panel_size() -> Vector2:
	return Vector2(880, 600)

func build_body(body: Control) -> void:
	var head := Label.new()
	head.text = "Konto: %.0f €   ·   Ruf: %.0f" % [Company.money, Company.reputation]
	body.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	for veh in Content.vehicles.values():
		var b := Button.new()
		var lvl := veh.required_company_level
		var ok_lvl := int(Company.data.company_level) >= lvl
		var afford := Company.money >= veh.purchase_price
		var status := "KAUFEN"
		if Company.owns_vehicle(veh.id):
			status = "✓ in der Flotte"
		elif not ok_lvl:
			status = "Level %d nötig" % lvl
		elif not afford:
			status = "zu teuer"
		b.text = "%s – %.0f €\n%.0f kg Ladekraft · Topspeed %d km/h · [%s]" % [
			veh.display_name, veh.purchase_price, veh.max_cargo_mass_kg,
			int(veh.top_speed_kmh), status,
		]
		b.custom_minimum_size = Vector2(0, 76)
		b.disabled = Company.owns_vehicle(veh.id) or not ok_lvl
		b.pressed.connect(func() -> void:
			if Company.buy_vehicle(veh):
				Sfx.ui_confirm()
				UI.banner("NEUER %s" % veh.display_name.to_upper())
				_rebuild())
		v.add_child(b)

func _rebuild() -> void:
	UI.close(UI.Overlay.SHOP_VEHICLE)
	UI.open(UI.Overlay.SHOP_VEHICLE)
