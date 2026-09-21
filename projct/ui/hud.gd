extends CanvasLayer
class_name GameHUD
## In-Game HUD (#55): Interaktionsprompt, Mission-Ziele, Geld/Rep/Wetter,
## Werkzeug-Slots, Ladeanzeige, Damage-Popups, Fadenkreuz. Reines Lesen via
## EventBus – keine Gameplay-Aufrufe (Dependency-Richtung UI -> Services ✓ #120).

var root: Control
var prompt_label: Label
var objective_box: VBoxContainer
var money_label: Label
var rep_label: Label
var level_label: Label
var weather_label: Label
var time_label: Label
var tool_bar: HBoxContainer
var cargo_label: Label
var crosshair: ColorRect
var toasts: VBoxContainer
var banner: Label
var banner_tween: Tween
var strain_bar: ProgressBar
var minimap: MapWidget

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = Style.ui_theme() if get_node_or_null(^"/root/Style") != null else Theme.new()

	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-200, -140)
	prompt_label.size = Vector2(400, 34)
	prompt_label.add_theme_font_size_override("font_size", 18)
	root.add_child(prompt_label)

	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.75)
	crosshair.size = Vector2(4, 4)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(crosshair)

	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top.position = Vector2(12, 10)
	var tv := VBoxContainer.new()
	top.add_child(tv)
	root.add_child(top)
	money_label = Label.new()
	rep_label = Label.new()
	level_label = Label.new()
	for l in [money_label, rep_label, level_label]:
		l.add_theme_font_size_override("font_size", 20)
		tv.add_child(l)

	var top_r := PanelContainer.new()
	top_r.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_r.position = Vector2(-220, 10)
	var rv := VBoxContainer.new()
	top_r.add_child(rv)
	root.add_child(top_r)
	weather_label = Label.new()
	time_label = Label.new()
	rv.add_child(weather_label)
	rv.add_child(time_label)

	objective_box = VBoxContainer.new()
	objective_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_box.position = Vector2(-360, 96)
	objective_box.size = Vector2(344, 200)
	root.add_child(objective_box)

	cargo_label = Label.new()
	cargo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cargo_label.position = Vector2(-260, -64)
	root.add_child(cargo_label)

	strain_bar = ProgressBar.new()
	strain_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	strain_bar.position = Vector2(-110, -86)
	strain_bar.size = Vector2(220, 10)
	strain_bar.show_percentage = false
	strain_bar.max_value = 1.0
	strain_bar.modulate = Color(1, 0.4, 0.2)
	root.add_child(strain_bar)

	tool_bar = HBoxContainer.new()
	tool_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tool_bar.position = Vector2(-190, -52)
	root.add_child(tool_bar)

	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toasts.position = Vector2(-230, 120)
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(toasts)

	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(-300, -40)
	banner.size = Vector2(600, 60)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 42)
	banner.modulate.a = 0.0
	root.add_child(banner)

	minimap = MapWidget.new()
	minimap.name = "Minimap"
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	minimap.position = Vector2(14, -178)
	minimap.size = Vector2(164, 164)
	root.add_child(minimap)

	EventBus.interaction_hover_changed.connect(_on_hover)
	EventBus.grab_strain_changed.connect(_on_strain)
	EventBus.mission_accepted.connect(func(_m) -> void: _refresh_objectives())
	EventBus.objective_completed.connect(func(_m, _id) -> void: _refresh_objectives())
	EventBus.mission_completed.connect(func(_m, _p) -> void: _refresh_objectives())
	EventBus.mission_cancelled.connect(func(_m) -> void: _refresh_objectives())
	EventBus.mission_failed.connect(func(_m, _r) -> void: _refresh_objectives())
	EventBus.money_changed.connect(func(amt, _d) -> void: money_label.text = "%.0f €" % amt)
	EventBus.reputation_changed.connect(func(r, _d) -> void: rep_label.text = "RUF %.0f" % r)
	EventBus.weather_changed.connect(func(k, i) -> void: weather_label.text = "WETTER %d (%d%%)" % [k, int(i * 100)])
	EventBus.time_of_day_changed.connect(func(h) -> void: time_label.text = "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)])
	EventBus.cargo_loaded.connect(func(_v, _c) -> void: _refresh_cargo())
	EventBus.cargo_unloaded.connect(func(_v, _c) -> void: _refresh_cargo())
	EventBus.damage_changed.connect(_on_damage_popup)

func _refresh_statics() -> void:
	money_label.text = "%.0f €" % Company.money
	rep_label.text = "RUF %.0f" % Company.reputation
	level_label.text = "LEVEL %d" % Company.company_level
	_refresh_objectives()
	_refresh_cargo()

func _on_hover(node: Node) -> void:
	if node == null:
		prompt_label.text = ""
		return
	if node is FurnitureBody:
		var fb := node as FurnitureBody
		var haul := fb.data.required_haulers if fb.data != null else 1
		prompt_label.text = "[RMB] Greifen – %s (%.0f kg, %d Träger)" % [fb.data.display_name if fb.data != null else "Möbel", fb.mass, haul]
	elif node is WorldDoor:
		prompt_label.text = "[E] Tür"
	else:
		prompt_label.text = "[E] Benutzen"
	# Interactable-Komponente?
	for c in node.get_children():
		if c is Interactable:
			prompt_label.text = "[E] %s" % (c as Interactable).prompt_text
			break

func _on_strain(_body: RigidBody3D, strain: float) -> void:
	strain_bar.value = clampf(strain, 0.0, 1.0)

func _on_damage_popup(body: RigidBody3D, percent: float, _cause: StringName) -> void:
	if not is_instance_valid(body):
		return
	if percent < 3.0:
		return
	var fb := body as FurnitureBody
	var label := "%d%%" % int(percent)
	if fb != null and fb.data != null:
		label = "%s: %d%% Schaden" % [fb.data.display_name, int(percent)]
	toast(label, 1.6)

func _refresh_objectives() -> void:
	for c in objective_box.get_children():
		c.queue_free()
	if not Missions.has_active_mission():
		return
	var m := Missions.active_mission
	var head := Label.new()
	head.text = "– %s –" % m.display_name
	head.add_theme_font_size_override("font_size", 17)
	objective_box.add_child(head)
	for o in m.objectives:
		var l := Label.new()
		l.text = "◇ %s" % o.description
		if o.optional:
			l.text = "◆ Bonus: %s" % o.description
		objective_box.add_child(l)
	var t := Label.new()
	t.name = "TimeLabel"
	objective_box.add_child(t)

func _process(_delta: float) -> void:
	if not Missions.has_active_mission():
		return
	var m := Missions.active_mission
	var rt := get_tree().get_first_node_in_group("world")
	if rt != null and rt is WorldRoot and (rt as WorldRoot).mission_runtime != null:
		var el := (rt as WorldRoot).mission_runtime._elapsed
		var tl := objective_box.get_node_or_null("TimeLabel") as Label
		if tl != null:
			var left := m.time_limit_seconds - el
			tl.text = "⏱ %02d:%02d übrig" % [int(maxf(left, 0)) / 60, int(maxf(left, 0)) % 60]
			if left < 0:
				tl.text = "⏱ ÜBERZOEGEN"

func _refresh_cargo() -> void:
	var w := get_tree().get_first_node_in_group("world") as WorldRoot
	if w == null or w.vehicle == null:
		cargo_label.text = ""
		return
	var v := w.vehicle
	var ratio := v.load_ratio()
	cargo_label.text = "Ladung: %.0f/%.0f kg (%d Stk)%s" % [v.total_load_kg(), v.data.max_cargo_mass_kg if v.data != null else 0, v.cargo_items.size(), "  ÜBERLADEN!" if v.overladen() else ""]
	cargo_label.modulate = Color(1, 0.35, 0.2) if ratio > 1.0 else Color.WHITE

# ------------------------------------------------------------------ toast --

func toast(text: String, seconds: float = 2.6) -> void:
	var panel := PanelContainer.new()
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(l)
	toasts.add_child(panel)
	var t := create_tween()
	t.tween_interval(seconds)
	t.tween_property(panel, "modulate:a", 0.0, 0.5)
	t.tween_callback(panel.queue_free)

func hint(text: String) -> void:
	prompt_label.text = text

func banner_text(text: String) -> void:
	banner.text = text
	if banner_tween != null:
		banner_tween.kill()
	banner.modulate.a = 1.0
	banner_tween = create_tween()
	banner_tween.tween_interval(1.6)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.8)

func set_tools(names: PackedStringArray, active_index: int) -> void:
	for c in tool_bar.get_children():
		c.queue_free()
	for i in names.size():
		var b := PanelContainer.new()
		b.size = Vector2(72, 56)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var num := Label.new()
		num.text = str(i + 1)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var nm := Label.new()
		nm.text = names[i]
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 11)
		v.add_child(num)
		v.add_child(nm)
		if i == active_index:
			b.modulate = Color(1.0, 0.82, 0.35)
		else:
			b.modulate = Color(1, 1, 1, 0.55)
		tool_bar.add_child(b)
