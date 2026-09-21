extends BaseScreen
class_name ClothesShopScreen
## Klamotten-Shop: Cosmetics kaufen + sofort am eigenen Ragdoll-Charakter
## tragen (CharacterService färbt Mesh-Materialien ein) (#15).

func _ready() -> void:
	title = "KLEIDUNG & STYLE"
	overlay_enum = UI.Overlay.SHOP_CLOTHES
	super()

func _panel_size() -> Vector2:
	return Vector2(820, 580)

func build_body(body: Control) -> void:
	var head := Label.new()
	head.text = "Konto: %.0f €   –   gekaufte Teile werden sofort angezogen" % Company.money
	body.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for c in Content.cosmetics.values():
		var b := Button.new()
		var owned := Company.has_purchased(c.id)
		var lvl_ok := int(Company.data.company_level) >= c.unlock_company_level
		b.text = "%s [%s]\n%s" % [c.display_name, _slot_name(c.slot), "✓ angezogen/geholt" if owned else ("%.0f €" % c.price if lvl_ok else "Level %d nötig" % c.unlock_company_level)]
		b.disabled = owned or not lvl_ok
		b.custom_minimum_size = Vector2(380, 92)
		b.pressed.connect(_buy.bind(c))
		grid.add_child(b)

func _slot_name(slot: int) -> String:
	match slot:
		0: return "Hut"
		1: return "Maske/Brille"
		2: return "Schal/Nacken"
		3: return "Rucksack"
		4: return "Oberteil"
		5: return "Hose"
		6: return "Handschuhe"
	return "Kosmetik"

func _buy(c: CosmeticData) -> void:
	if Company.purchase_cosmetic(c):
		Characters.equip_cosmetic(c.id)
		Sfx.ui_confirm()
		UI.toast("%s angezogen!" % c.display_name)
		_rebuild()
	else:
		UI.toast("Das können wir uns nicht leisten.")

func _rebuild() -> void:
	UI.close(UI.Overlay.SHOP_CLOTHES)
	UI.open(UI.Overlay.SHOP_CLOTHES)
