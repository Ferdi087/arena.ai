extends Control
class_name BaseScreen
## Basisklasse aller Overlay-Screens: dunkles Panel, Titel, Close-Button,
## mausfähig, Esc = schließen. Screens bleiben klein; Logik in Services.

var overlay_enum: int = -1
var title: String = "FENSTER"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if get_node_or_null("Dim") == null:
		var dim := ColorRect.new()
		dim.name = "Dim"
		dim.color = Color(0.0, 0.0, 0.0, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
		var panel := PanelContainer.new()
		panel.name = "Panel"
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.custom_minimum_size = Vector2(_panel_size().x, _panel_size().y)
		panel.position = (get_viewport_rect().size - _panel_size()) * 0.5
		add_child(panel)
		var outer := VBoxContainer.new()
		panel.add_child(outer)
		var header := HBoxContainer.new()
		outer.add_child(header)
		var title_l := Label.new()
		title_l.text = "» " + title
		title_l.add_theme_font_size_override("font_size", 26)
		title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title_l)
		var close_b := Button.new()
		close_b.text = "✕  ESC"
		close_b.pressed.connect(_close)
		header.add_child(close_b)
		var body := VBoxContainer.new()
		body.name = "Body"
		body.add_theme_constant_override("separation", 8)
		outer.add_child(body)
		build_body(body)

func _panel_size() -> Vector2:
	return Vector2(760, 560)

func build_body(_body: Control) -> void:
	pass

func _close() -> void:
	Sfx.ui_click()
	if overlay_enum >= 0:
		UI.close(overlay_enum as UI.Overlay)

func add_list_row(parent: Control, left_text: String, right_action: String, cb: Callable) -> Button:
	var row := Button.new()
	row.text = "%s                                    %s" % [left_text, right_action]
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.pressed.connect(cb)
	parent.add_child(row)
	return row
