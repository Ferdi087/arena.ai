extends BaseScreen
class_name PaintPaletteScreen
## Farb-Palette für Sprüher/Baumodus: 12 Dosenfarben, Muster, Düsengröße.
## Schreibt direkt in die ToolController des lokalen Spielers (paint_color,
## pattern, paint_size_mult) – Sprühwerkzeug bleibt aktiv.

const PAINT_COLORS: Array[Color] = [
	Color("#e74c3c"), Color("#e67e22"), Color("#f1c40f"), Color("#2ecc71"),
	Color("#1abc9c"), Color("#3498db"), Color("#9b59b6"), Color("#e84393"),
	Color("#ecf0f1"), Color("#95a5a6"), Color("#34495e"), Color("#2d3436"),
]
const PATTERNS: Array[StringName] = [&"solid", &"stripes", &"dots", &"glow"]

var _size_label: Label

func _ready() -> void:
	title = "FARBEN & PENSEL"
	overlay_enum = UI.Overlay.PALETTE
	super()

func _panel_size() -> Vector2:
	return Vector2(560, 480)

func build_body(body: Control) -> void:
	var hint := Label.new()
	hint.text = "Farbe wählen – Sprühen bleibt aktiv. Esc schließen."
	body.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 4
	body.add_child(grid)
	for c in PAINT_COLORS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 70)
		b.flat = true
		b.self_modulate = c
		b.tooltip_text = "#%s" % c.to_html(false)
		var col := c
		b.pressed.connect(func() -> void:
			_tools().set_paint_color(col)
			Sfx.ui_click())
		grid.add_child(b)
	body.add_child(HSeparator.new())
	var prow := HBoxContainer.new()
	body.add_child(prow)
	var pl := Label.new()
	pl.text = "Muster:"
	prow.add_child(pl)
	for p in PATTERNS:
		var pb := Button.new()
		pb.text = String(p)
		var pp := p
		pb.pressed.connect(func() -> void:
			_tools().set_pattern(pp)
			Sfx.ui_click())
		prow.add_child(pb)
	var size_row := HBoxContainer.new()
	body.add_child(size_row)
	var sl := Label.new()
	sl.text = "Düsengröße"
	size_row.add_child(sl)
	var slider := HSlider.new()
	slider.min_value = 0.4
	slider.max_value = 3.0
	slider.step = 0.1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(vv: float):
		_tools().paint_size_mult = vv
		if _size_label != null:
			_size_label.text = "%.1f×" % vv)
	size_row.add_child(slider)
	_size_label = Label.new()
	_size_label.text = "1.0×"
	size_row.add_child(_size_label)
	var note := Label.new()
	note.text = "Farben & Muster werden auf dem getränkten Object-Paint-Overlay\ngerendert (paint_overlay.gdshader) und im Savegame pro Objekt gesichert."
	note.modulate = Color(0.7, 0.75, 0.85)
	body.add_child(note)

func _tools() -> ToolController:
	var p := get_tree().get_first_node_in_group("players")
	if p != null:
		var t := p.get_node_or_null("Tools") as ToolController
		if t != null:
			return t
	return _fallback_tools

var _fallback_tools: ToolController

func _init() -> void:
	_fallback_tools = ToolController.new()
