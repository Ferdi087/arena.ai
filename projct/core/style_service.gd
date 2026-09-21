extends Node
## Style Service (Autoload "Style") – EIN Ort für Look: Outlines, Basismaterialien,
## Paint-Materialien, UI-Theme. (#58/#129)
##
## Outline = Inverted Hull über material_next_pass (bewusste Wahl, s. Shader-Header).
## Materialien werden pro Data-Resource gecacht; Paint-Instanzen pro Objekt geklont.
## Settings.outline_enabled schaltet global ohne Szenen-Rebuild um: Wir setzen
## die Shader-Width auf 0 – billiger als Material-Rebuild und netzwerkneutral.

const OUTLINE_SHADER := "res://shaders/outline_invert_hull.gdshader"
const PAINT_SHADER := "res://shaders/paint_overlay.gdshader"

var _mat_cache: Dictionary[StringName, StandardMaterial3D] = {}
var _next_pass_cache: ShaderMaterial = null
var _paint_shader: Shader = null
var _outline_width_default := 0.014

func _ready() -> void:
	Settings.settings_changed.connect(_on_settings_changed)

func _on_settings_changed() -> void:
	if _next_pass_cache != null:
		_next_pass_cache.set_shader_parameter("width", 0.0 if not Settings.outline_enabled else _outline_width_default)
		# Alle gecachten Materialien teilen sich _next_pass_cache (dieselbe
		# Resource-Instanz) -> ein Setzen der Width wirkt global und sofort.

func get_outline_material(width_scale: float = 1.0) -> ShaderMaterial:
	if _next_pass_cache == null:
		var shader := load(OUTLINE_SHADER) as Shader
		if shader == null:
			push_error("Style: Outline-Shader fehlt: %s" % OUTLINE_SHADER)
			return null
		_next_pass_cache = ShaderMaterial.new()
		_next_pass_cache.shader = shader
		_next_pass_cache.set_shader_parameter("width", _outline_width_default * width_scale if Settings.outline_enabled else 0.0)
		_next_pass_cache.set_shader_parameter("outline_color", Vector4(0.02, 0.02, 0.035, 1.0))
	return _next_pass_cache

## Basis-StandardMaterial für prozeduralen Kram, gecached pro (id,color).
func get_flat_material(key: StringName, color: Color, rough: float = 0.72, metal: float = 0.0) -> StandardMaterial3D:
	var cache_key := StringName("%s_%s_%0.2f" % [key, color.to_html(), rough])
	if _mat_cache.has(cache_key):
		return _mat_cache[cache_key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.next_pass = get_outline_material()
	_mat_cache[cache_key] = m
	return m

## ShaderMaterial mit Paint-Overlay (Objekt-Instanzen; Texture wird gesetzt).
func make_paint_material(base_color: Color, size_hint: Vector3) -> ShaderMaterial:
	if _paint_shader == null:
		_paint_shader = load(PAINT_SHADER) as Shader
		if _paint_shader == null:
			push_error("Style: Paint-Shader fehlt: %s" % PAINT_SHADER)
			return null
	var m := ShaderMaterial.new()
	m.shader = _paint_shader
	m.set_shader_parameter("base_color", Vector4(base_color.r, base_color.g, base_color.b, base_color.a))
	m.set_shader_parameter("paint_center", Vector3.ZERO)
	m.set_shader_parameter("paint_size", size_hint)
	m.next_pass = get_outline_material()
	return m

func ui_theme() -> Theme:
	## Kompakter, "kommerzieller" Theme-Aufbau ohne Theme-Asset-Dateien.
	var t := Theme.new()
	t.default_font_size = 17
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.08, 0.11, 0.94)
	panel.border_color = Color(0.95, 0.62, 0.12, 0.9)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 18.0
	panel.content_margin_right = 18.0
	panel.content_margin_top = 14.0
	panel.content_margin_bottom = 14.0
	t.set_stylebox("panel", "PanelContainer", panel)

	var btn_n := StyleBoxFlat.new()
	btn_n.bg_color = Color(0.13, 0.15, 0.2, 0.95)
	btn_n.border_color = Color(0.95, 0.62, 0.12, 0.25)
	btn_n.set_border_width_all(1)
	btn_n.set_corner_radius_all(6)
	btn_n.content_margin_left = 16.0
	btn_n.content_margin_right = 16.0
	btn_n.content_margin_top = 7.0
	btn_n.content_margin_bottom = 7.0
	var btn_h := btn_n.duplicate() as StyleBoxFlat
	btn_h.bg_color = Color(0.95, 0.62, 0.12, 0.25)
	btn_h.border_color = Color(0.95, 0.62, 0.12, 1.0)
	var btn_p := btn_n.duplicate() as StyleBoxFlat
	btn_p.bg_color = Color(0.95, 0.62, 0.12, 0.45)
	var btn_d := btn_n.duplicate() as StyleBoxFlat
	btn_d.bg_color = Color(0.09, 0.1, 0.13, 0.7)
	btn_d.border_color = Color(0.4, 0.4, 0.45, 0.3)
	t.set_stylebox("normal", "Button", btn_n)
	t.set_stylebox("hover", "Button", btn_h)
	t.set_stylebox("pressed", "Button", btn_p)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", btn_d)
	t.set_color("font_color", "Button", Color(0.93, 0.94, 0.97))
	t.set_color("hover_font_color", "Button", Color(1, 0.78, 0.25))
	t.set_color("font_color", "Label", Color(0.9, 0.91, 0.94))
	t.set_color("font_color", "LineEdit", Color(0.95, 0.96, 0.98))
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.04, 0.045, 0.06, 1.0)
	le.border_color = Color(0.95, 0.62, 0.12, 0.6)
	le.set_border_width_all(1)
	le.set_corner_radius_all(5)
	le.content_margin_left = 8.0
	le.content_margin_top = 4.0
	le.content_margin_bottom = 4.0
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.1, 0.11, 0.14)
	sb_n.set_corner_radius_all(4)
	sb_n.set_border_width_all(0)
	var sb_g := StyleBoxFlat.new()
	sb_g.bg_color = Color(0.95, 0.62, 0.12)
	sb_g.set_corner_radius_all(4)
	t.set_stylebox("slider", "HSlider", sb_n)
	t.set_stylebox("grabber_area", "HSlider", sb_g)
	t.set_color("font_color", "RichTextLabel", Color(0.9, 0.91, 0.94))
	var win := StyleBoxFlat.new()
	win.bg_color = Color(0.05, 0.055, 0.07, 0.97)
	win.border_color = Color(0.95, 0.62, 0.12, 0.8)
	win.set_border_width_all(2)
	win.set_corner_radius_all(10)
	win.content_margin_left = 20.0
	win.content_margin_right = 20.0
	win.content_margin_top = 16.0
	win.content_margin_bottom = 16.0
	t.set_stylebox("panel", "AcceptDialog", win)
	return t
