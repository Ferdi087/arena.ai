extends Control
class_name CompanySetupScreen
## Neugründungs-Assistent: Name, Slogan, Markenfarbe, Logo-Würfel,
## Website-Theme – schreibt direkt in Company (begin_new_company + set_website).
## Danach: Charakter-Creator.

const BRAND_COLORS: Array[Color] = [
	Color(0.95, 0.6, 0.1), Color(0.9, 0.25, 0.25), Color(0.25, 0.65, 0.35),
	Color(0.25, 0.45, 0.85), Color(0.6, 0.35, 0.75), Color(0.9, 0.8, 0.2),
]

var _name_edit: LineEdit
var _slogan_edit: LineEdit
var _about_edit: LineEdit
var _brand_color: Color = BRAND_COLORS[0]
var _theme: StringName = &"budget"
var _logo_rect: TextureRect
var _preview_label: Label
var _seed: int = randi() % 100000

func _ready() -> void:
	Game.change_state(Game.AppState.COMPANY_SETUP)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 600)
	c.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := Label.new()
	head.text = "FIRMENGRÜNDUNG"
	head.add_theme_font_size_override("font_size", 34)
	head.add_theme_color_override("font_color", Color(1, 0.72, 0.16))
	v.add_child(head)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(_lab("Firmenname"))
	_name_edit = LineEdit.new()
	_name_edit.text = "Möbel-Rambo GmbH"
	_name_edit.max_length = 28
	_name_edit.text_changed.connect(func(_t: String): _refresh_logo())
	left.add_child(_name_edit)
	left.add_child(_lab("Slogan"))
	_slogan_edit = LineEdit.new()
	_slogan_edit.text = "Wir schleppen, bis es kracht."
	_slogan_edit.max_length = 44
	_slogan_edit.text_changed.connect(func(_t: String): _refresh_logo())
	left.add_child(_slogan_edit)
	left.add_child(_lab("Über uns (kurz)"))
	_about_edit = LineEdit.new()
	_about_edit.placeholder_text = "Familienbetrieb seit 2026 – 100 % Wucht, 0 % Halbe Sache."
	left.add_child(_about_edit)
	left.add_child(_lab("Markenfarbe"))
	var crow := HBoxContainer.new()
	left.add_child(crow)
	for cc in BRAND_COLORS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 30)
		b.self_modulate = cc
		var col := cc
		b.pressed.connect(func() -> void:
			_brand_color = col
			_refresh_logo())
		crow.add_child(b)
	left.add_child(_lab("Website-Stil"))
	var trow := HBoxContainer.new()
	left.add_child(trow)
	for t in ["budget", "clean", "flashy", "luxury"]:
		var b := Button.new()
		b.text = String(t)
		var tn := StringName(t)
		b.pressed.connect(func() -> void:
			_theme = tn
			_refresh_logo())
		trow.add_child(b)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	row.add_child(right)
	var pv := PanelContainer.new()
	pv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(pv)
	var pvv := VBoxContainer.new()
	pv.add_child(pvv)
	_logo_rect = TextureRect.new()
	_logo_rect.custom_minimum_size = Vector2(256, 256)
	_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pvv.add_child(_logo_rect)
	_preview_label = Label.new()
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pvv.add_child(_preview_label)
	var dice := Button.new()
	dice.text = "🎲 Anderes Logo-Würfeln"
	dice.pressed.connect(func() -> void:
		_seed = randi() % 100000
		_refresh_logo())
	right.add_child(dice)
	var next_b := Button.new()
	next_b.text = "WEITER → CHARAKTER"
	next_b.custom_minimum_size = Vector2(0, 54)
	next_b.pressed.connect(_next)
	v.add_child(next_b)
	var back := Button.new()
	back.text = "← Zurück ins Hauptmenü"
	back.pressed.connect(func() -> void:
		Scenes.change_scene("res://scenes/menus/main_menu.tscn"))
	v.add_child(back)
	_refresh_logo()

func _lab(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l

func _refresh_logo() -> void:
	# Preview schreibt direkt in Company.data (begin_new_company in _next setzt
	# ohnehin final) – so nutzt logo_image genau die Werte, die man sieht.
	Company.data.logo_seed = _seed
	Company.data.brand_color = _brand_color
	Company.data.slogan = _slogan_edit.text
	Company.data.website_theme = _theme
	_logo_rect.texture = Company.logo_image(256)
	if _preview_label != null:
		_preview_label.text = "%s\n„%s“\nTheme: %s" % [_name_edit.text, _slogan_edit.text, String(_theme)]

func _next() -> void:
	Sfx.ui_confirm()
	# Company-Reset hier (NICHT erst in Game.start_new_game, damit Website &
	# Name den Reset überleben – der Creator stülpt nur drüber).
	Company.begin_new_company(_name_edit.text)
	Company.data.slogan = _slogan_edit.text
	Company.data.logo_seed = _seed
	Company.data.website_theme = _theme
	Company.data.brand_color = _brand_color
	Company.data.website_about_text = _about_edit.text
	Game.game_seed = _seed
	Scenes.change_scene("res://scenes/menus/character_creator.tscn")
