extends Control
class_name CharacterCreatorScreen
## Charakter-Ersteller: 3D-Vorschau eines Ragdoll-Puppen-Rohlings im
## SubViewport + Slider für Morphs/Farben (CharacterData). Werte wirken SOFORT
## auf Vorschau und werden als Characters.current_character übernommen.

var _data: CharacterData = null
var _model: Node3D = null
var _spin: float = 0.0

const SKIN_COLORS: Array[Color] = [
	Color(0.96, 0.78, 0.62), Color(0.82, 0.6, 0.44), Color(0.55, 0.36, 0.24),
	Color(0.34, 0.21, 0.14), Color(0.99, 0.87, 0.75),
]

func _ready() -> void:
	Game.change_state(Game.AppState.CHARACTER_CREATOR)
	_data = Characters.current_character.duplicate(true) as CharacterData
	if _data == null:
		_data = CharacterData.new()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var split := HSplitContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(split)
	# --- 3D-Preview ---
	var host := SubViewportContainer.new()
	host.stretch = true
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(host)
	var vp := SubViewport.new()
	vp.transparent_background = false
	host.add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.85, 0.8)
	env.ambient_light_energy = 0.6
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.15, 3.1)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	cam.fov = 60
	vp.add_child(cam)
	cam.make_current()
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, 30, 0)
	key.shadow_enabled = true
	vp.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2, 2, 2)
	fill.omni_range = 6.0
	vp.add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(8, 8)
	floor_mi.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.16, 0.18, 0.24)
	fmat.roughness = 0.95
	floor_mi.material_override = fmat
	vp.add_child(floor_mi)
	_model = Node3D.new()
	vp.add_child(_model)
	# --- Controls ---
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 0)
	split.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var head := Label.new()
	head.text = "CHARAKTER"
	head.add_theme_font_size_override("font_size", 30)
	v.add_child(head)
	var nl := LineEdit.new()
	nl.text = _data.display_name
	nl.placeholder_text = "Name"
	nl.text_changed.connect(func(t: String): _data.display_name = t)
	v.add_child(nl)
	_slider(v, "Größe", "height")
	_slider(v, "Breite", "width")
	_slider(v, "Bauch", "belly")
	_slider(v, "Schultern", "shoulder_width")
	_slider(v, "Kopfgröße", "head_size")
	_slider(v, "Arme", "arm_length")
	_slider(v, "Beine", "leg_length")
	_slider(v, "Gewichtsklasse", "weight_class")
	var cl := Label.new()
	cl.text = "Hautfarbe"
	v.add_child(cl)
	var crow := HBoxContainer.new()
	v.add_child(crow)
	for c in SKIN_COLORS:
		var b := Button.new()
		b.self_modulate = c
		b.custom_minimum_size = Vector2(40, 26)
		var col := c
		b.pressed.connect(func(): _data.skin_color = col; _rebuild_model())
		crow.add_child(b)
	_color_row(v, "Oberteil", "shirt_color")
	_color_row(v, "Hose", "pants_color")
	var go := Button.new()
	go.text ="LOS GEHT'S – INS HQ 🚚"
	go.custom_minimum_size = Vector2(0, 52)
	go.pressed.connect(_finish)
	v.add_child(go)
	var back := Button.new()
	back.text = "← zurück"
	back.pressed.connect(func(): Scenes.change_scene("res://scenes/menus/company_setup.tscn"))
	v.add_child(back)
	_rebuild_model()

func _slider(parent: Control, label: String, prop: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = " %s" % label
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.value = float(_data.get(prop))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(vv: float):
		_data.set(prop, vv)
		_rebuild_model())
	row.add_child(sl)

func _color_row(parent: Control, label: String, prop: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = " %s" % label
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var cp := ColorPickerButton.new()
	cp.color = _data.get(prop) as Color
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cp.popup_closed.connect(func():
		_data.set(prop, cp.color)
		_rebuild_model())
	row.add_child(cp)

func _rebuild_model() -> void:
	for c in _model.get_children():
		c.queue_free()
	_add_box(Vector3(0, 1.05 + 0.18 * (_data.height - 0.5), 0),
		Vector3(0.42 + 0.2 * _data.width + 0.16 * _data.shoulder_width, 0.55, 0.28 + 0.1 * _data.belly),
		_data.shirt_color, 2.2 + _data.height * 0.6)
	_add_box(Vector3(0, 0.98 + 0.12 * (_data.height - 0.5), 0.17 + 0.1 * _data.belly),
		Vector3(0.36, 0.2, 0.14 + 0.12 * _data.belly), _data.shirt_color.lightened(0.1), 2.1)
	var head_y := 1.45 + 0.18 * _data.height
	_add_box(Vector3(0, head_y, 0), Vector3(0.26, 0.26, 0.24) * (0.8 + _data.head_size * 0.6), _data.skin_color, 2.5)
	var leg_h := 0.5 + 0.35 * _data.leg_length
	_add_box(Vector3(-0.12, leg_h * 0.5, 0), Vector3(0.16, leg_h, 0.18), _data.pants_color, 1.6)
	_add_box(Vector3(0.12, leg_h * 0.5, 0), Vector3(0.16, leg_h, 0.18), _data.pants_color, 1.6)
	var arm_y := 1.05 + 0.18 * (_data.height - 0.5)
	var arm_l := 0.35 + 0.3 * _data.arm_length
	_add_box(Vector3(-0.34 - 0.06 * _data.shoulder_width, arm_y - arm_l * 0.4, 0), Vector3(0.12, arm_l, 0.14), _data.shirt_color, 1.8)
	_add_box(Vector3(0.34 + 0.06 * _data.shoulder_width, arm_y - arm_l * 0.4, 0), Vector3(0.12, arm_l, 0.14), _data.shirt_color, 1.8)
	_add_box(Vector3(-0.34 - 0.06 * _data.shoulder_width, arm_y - arm_l, 0), Vector3(0.14, 0.12, 0.16) * (0.8 + _data.hand_size * 0.5), _data.skin_color, 2.4)
	_add_box(Vector3(0.34 + 0.06 * _data.shoulder_width, arm_y - arm_l, 0), Vector3(0.14, 0.12, 0.16) * (0.8 + _data.hand_size * 0.5), _data.skin_color, 2.4)

func _add_box(pos: Vector3, size3: Vector3, col: Color, rough: float) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size3
	mi.mesh = m
	mi.position = pos
	var mat: StandardMaterial3D = Style.get_flat_material(&"cc_%d" % (mi.get_instance_id()), col, clampf(rough * 0.35, 0.2, 1.0))
	mi.material_override = mat
	_model.add_child(mi)

func _process(delta: float) -> void:
	_spin += delta * 0.35
	if _model != null:
		_model.rotation_degrees = Vector3(0, sin(_spin) * 24.0, 0)

func _finish() -> void:
	Sfx.ui_confirm()
	Characters.set_character(_data)
	Game.change_state(Game.AppState.LOADING)
	Scenes.change_scene("res://scenes/world/hq.tscn", func() -> void:
		Game.change_state(Game.AppState.IN_GAME))
