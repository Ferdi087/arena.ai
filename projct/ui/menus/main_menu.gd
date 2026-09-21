extends Control
class_name MainMenu
## Hauptmenü – im Code gebaut (keine .tscn-Abhängigkeit außer der Wurzel).
## Hintergrund: prozedurale Skyline via _draw, slowly scrollende Truck-Silhouette.
## Zuständig nur für Einstieg: Neues Spiel (Company Setup), Laden, Coop, Optionen.

var _bg_t: float = 0.0
var _has_save: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.change_state(Game.AppState.MAIN_MENU)
	UI.detach_hud()
	SplitScreen.detach_all()
	Net.shutdown()
	_has_save = not Saves.slot_info(Saves.active_slot).is_empty()
	for s in range(Saves.MAX_SLOTS):
		if not Saves.slot_info(s).is_empty():
			_has_save = true
	GameInput.release_mouse()
	_build()

func _build() -> void:
	var logo := Label.new()
	logo.name = "Logo"
	logo.text = "MÖBEL-RAMBO\nUMZUGSSERVICE-SIMULATOR"
	logo.add_theme_font_size_override("font_size", 64)
	logo.add_theme_color_override("font_color", Color(1, 0.72, 0.16))
	logo.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	logo.add_theme_constant_override("outline_size", 14)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.position = Vector2(0, 90)
	logo.size = Vector2(get_viewport_rect().size.x, 160)
	add_child(logo)
	var sub := Label.new()
	sub.text = "Greifen. Wuchten. Abladen. Ankommen."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.8, 0.85, 0.95)
	sub.position = Vector2(0, 250)
	sub.size = Vector2(get_viewport_rect().size.x, 30)
	add_child(sub)
	var col := VBoxContainer.new()
	col.name = "Buttons"
	col.position = Vector2(70, get_viewport_rect().size.y - 330)
	col.custom_minimum_size = Vector2(360, 0)
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	_btn(col, "NEUES UNTERNEHMEN", func() -> void:
		Scenes.change_scene("res://scenes/menus/company_setup.tscn"), true)
	_btn(col, "FORTSETZEN (%s)" % ("Spielstand Slot %d" % (Saves.active_slot + 1) if _has_save else "kein Spielstand"), _continue, _has_save)
	_btn(col, "STAND LADEN …", func() -> void: _load_menu(), _has_save)
	_btn(col, "LOKALER CO-OP (2 Spieler, Splitscreen)", func() -> void:
		Game.local_coop_players = 2
		Scenes.change_scene("res://scenes/menus/company_setup.tscn"))
	_btn(col, "ONLINE CO-OP (Demo-Host)", func() -> void:
		Game.local_coop_players = 1
		if Net.host_game():
			Scenes.change_scene("res://scenes/menus/company_setup.tscn")
		else:
			UI.toast("Hosting nicht verfügbar (kein UPnP/Port?) – bitte lokal testen."))
	_btn(col, "EINSTELLUNGEN", func() -> void:
		var f := _overlay()
		var s := SettingsScreen.new()
		s.title = "EINSTELLUNGEN (Menü)"
		f.add_child(s))
	_btn(col, "EXTRAS", func() -> void:
		var f := _overlay()
		f.add_child(ExtrasScreen.new()))
	_btn(col, "CREDITS", func() -> void:
		var f := _overlay()
		f.add_child(CreditsScreen.new()))
	_btn(col, "BEENDEN", func() -> void: get_tree().quit())
	var ver := Label.new()
	ver.text = "Vertical-Slice-Build · Godot 4 · Physik: Jolt · alle Optionen wirksam"
	ver.modulate = Color(0.55, 0.6, 0.7)
	ver.position = Vector2(get_viewport_rect().size.x - 480, get_viewport_rect().size.y - 34)
	add_child(ver)

func _overlay() -> Control:
	var f := Control.new()
	f.name = "MenuOverlay"
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(f)
	return f

func _btn(parent: Control, text: String, cb: Callable, enabled: bool = true) -> void:
	var b := Button.new()
	b.text = "  %s" % text
	b.custom_minimum_size = Vector2(0, 48)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not enabled
	b.pressed.connect(func() -> void:
		Sfx.ui_confirm()
		cb.call())
	parent.add_child(b)

func _continue() -> void:
	if not _has_save:
		return
	if Saves.load_slot(Saves.active_slot):
		Game.change_state(Game.AppState.LOADING)
		Scenes.change_scene("res://scenes/world/hq.tscn", func() -> void:
			Game.change_state(Game.AppState.IN_GAME))

func _load_menu() -> void:
	var f := _overlay()
	var s := SaveLoadScreen.new()
	s.mode_save = false
	f.add_child(s)

func _process(delta: float) -> void:
	_bg_t += delta
	queue_redraw()

func _draw() -> void:
	var sz := get_viewport_rect().size
	# Himmel-Gradient
	for i in 24:
		var t := float(i) / 24.0
		var c := Color(0.06 + 0.1 * t, 0.08 + 0.06 * t, 0.14 + 0.1 * t)
		draw_rect(Rect2(0, sz.y * t * 0.75, sz.x, sz.y * 0.75 / 24.0 + 1.0), c)
	# Sonnenuntergangsglühen
	draw_circle(Vector2(sz.x * 0.78, sz.y * 0.52), 190.0, Color(0.95, 0.5, 0.2, 0.14))
	draw_circle(Vector2(sz.x * 0.78, sz.y * 0.52), 90.0, Color(1.0, 0.66, 0.3, 0.25))
	# Skyline zwei Ebenen
	var base_y := sz.y * 0.75
	_skyline(base_y + 30.0, Color(0.07, 0.08, 0.12), 66.0, _bg_t * 4.0, 7)
	_skyline(base_y + 74.0, Color(0.04, 0.05, 0.075), 44.0, _bg_t * 11.0 + 23.0, 11)
	# Boden
	draw_rect(Rect2(0, base_y + 96.0, sz.x, sz.y), Color(0.03, 0.035, 0.05))
	# Truck-Silhouette die von rechts nach links fährt
	var tx := fmod(sz.x + 300.0 - _bg_t * 90.0, sz.x + 500.0) - 250.0
	var ty := base_y + 96.0
	var truck := Color(0.02, 0.02, 0.03)
	draw_rect(Rect2(tx, ty - 34.0, 96.0, 30.0), truck)
	draw_rect(Rect2(tx + 96.0, ty - 26.0, 30.0, 22.0), truck)
	draw_circle(Vector2(tx + 22.0, ty - 2.0), 8.0, truck)
	draw_circle(Vector2(tx + 108.0, ty - 2.0), 8.0, truck)
	draw_rect(Rect2(tx + 2.0, ty - 32.0, 60.0, 6.0), Color(1, 0.72, 0.16, 0.5))

func _skyline(base_y: float, col: Color, step: float, off: float, seedoff: int) -> void:
	var sz := get_viewport_rect().size
	var x := fmod(-off, step) - step
	while x < sz.x + step:
		var rnd := int(x * 31.7 + seedoff * 113.3)
		rnd = absi(rnd % 97)
		var h := 40.0 + float(rnd % 56)
		draw_rect(Rect2(x, base_y - h, step - 6.0, h + 120.0), col)
		if rnd % 3 == 0:
			draw_rect(Rect2(x + 8.0, base_y - h + 10.0, 6.0, 6.0), Color(1, 0.85, 0.5, 0.15))
		x += step
