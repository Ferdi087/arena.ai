extends BaseScreen
class_name BuildShopScreen
## Baumarkt: alle HQ-Bauteile im Katalog + Preis-Info; das Platzieren selbst
## passiert im BuildMode (B) – dieser Screen ist die Referenz & Bezugsquelle
## (Quality-of-Life: Palette öffnet sich direkt).

func _ready() -> void:
	title = "BAUMARKT – HQ-AUSSTATTUNG"
	overlay_enum = UI.Overlay.SHOP_BUILD
	super()

func _panel_size() -> Vector2:
	return Vector2(900, 620)

func build_body(body: Control) -> void:
	var head := Label.new()
	head.text = "Konto: %.0f € – Kaufen = im Baumodus verfügbar & wird pro Platzierung abgerechnet." % Company.money
	body.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for piece in Content.build_pieces.values():
		var card := PanelContainer.new()
		var col := VBoxContainer.new()
		card.add_child(col)
		var name_l := Label.new()
		name_l.text = piece.display_name
		name_l.add_theme_font_size_override("font_size", 17)
		col.add_child(name_l)
		var kind_l := Label.new()
		kind_l.text = _kind_name(piece.kind)
		kind_l.modulate = Color(0.7, 0.8, 0.9)
		col.add_child(kind_l)
		var price_l := Label.new()
		price_l.text = "%.0f € · Level %d" % [piece.cost, piece.required_company_level]
		col.add_child(price_l)
		var c := Color(0.85, 0.55, 0.2)
		match piece.kind:
			BuildPieceData.Kind.WALL: c = Color(0.75, 0.72, 0.68)
			BuildPieceData.Kind.FLOOR: c = Color(0.55, 0.4, 0.25)
			BuildPieceData.Kind.CEILING: c = Color(0.8, 0.78, 0.74)
			BuildPieceData.Kind.DOOR: c = Color(0.5, 0.3, 0.15)
			BuildPieceData.Kind.WINDOW: c = Color(0.6, 0.85, 0.95)
			BuildPieceData.Kind.STAIR: c = Color(0.5, 0.5, 0.55)
			BuildPieceData.Kind.LIGHT: c = Color(1.0, 0.9, 0.6)
			BuildPieceData.Kind.WORKBENCH: c = Color(0.65, 0.45, 0.3)
		var sw := ColorRect.new()
		sw.color = c
		sw.custom_minimum_size = Vector2(0, 26)
		col.add_child(sw)
		grid.add_child(card)

func _kind_name(kind: int) -> String:
	match kind:
		0: return "Wand"
		1: return "Boden"
		2: return "Decke"
		3: return "Tür"
		4: return "Fenster"
		5: return "Treppe"
		6: return "Deko"
		7: return "Licht"
		8: return "Werkbank"
	return "Bauteil"
