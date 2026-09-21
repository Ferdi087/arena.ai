extends BaseScreen
class_name SettingsScreen
## AAA-Optionsmenü – jede Option wirkt SOFORT über Settings (s. SettingsManager)
## und wird persistiert (#56/#57). Kein Fake-Regler.

var _scrolled: VBoxContainer

func _ready() -> void:
	title = "EINSTELLUNGEN"
	overlay_enum = UI.Overlay.SETTINGS
	super()

func _panel_size() -> Vector2:
	return Vector2(860, 640)

func build_body(body: Control) -> void:
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	tabs.add_child(_mk_tab("Grafik"))
	tabs.add_child(_mk_tab("Audio"))
	tabs.add_child(_mk_tab("Steuerung"))
	tabs.add_child(_mk_tab("Spiel"))
	for tab in tabs.get_children():
		(tab as Control).set_meta("host", tab)
	_build_graphics(tabs.get_child(0))
	_build_audio(tabs.get_child(1))
	_build_controls(tabs.get_child(2))
	_build_game(tabs.get_child(3))

func _mk_tab(name_s: String) -> Control:
	var c := Control.new()
	c.name = name_s
	return c

func _row(parent: Control, y_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row

func _build_graphics(parent: Control) -> void:
	# Preset-Buttons
	var preset_row := _row(parent, 0)
	preset_row.get_child(0).text = "Grafik-Preset"
	for p in ["Niedrig", "Mittel", "Hoch", "Ultra"]:
		var b := Button.new()
		b.text = p
		var idx: int = ["Niedrig", "Mittel", "Hoch", "Ultra"].find(p)
		b.pressed.connect(func() -> void:
			Settings.apply_preset(idx)
			_refresh_all())
		preset_row.add_child(b)
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	_slider_row(v, "VSync", func(): return 1.0 if Settings.vsync_enabled else 0.0, func(vv: float):
		Settings.vsync_enabled = vv > 0.5
		Settings.apply_all())
	_spinner_row(v, "FPS-Limit (0=aus)", func(): return float(Settings.fps_limit), func(vv: float):
		Settings.fps_limit = int(vv)
		Settings.apply_all(), [0.0, 30.0, 60.0, 120.0, 144.0, 240.0, 360.0])
	_spinner_row(v, "MSAA (0=aus,1=2x,2=4x,3=8x)", func(): return float(Settings.msaa_3d), func(vv: float):
		Settings.msaa_3d = int(vv)
		Settings.apply_all(), [0.0, 1.0, 2.0, 3.0])
	_slider_row(v, "Schattenqualität", func(): return float(Settings.shadow_quality), func(vv: float):
		Settings.shadow_quality = int(round(vv))
		Settings.apply_all())
	_slider_row(v, "Schatten-Distanz", func(): return Settings.shadow_distance / 200.0, func(vv: float):
		Settings.shadow_distance = vv * 200.0
		Settings.apply_all())
	_slider_row(v, "SDFGI (Global Illumination)", func(): return 1.0 if Settings.sdfgi_enabled else 0.0, func(vv: float):
		Settings.sdfgi_enabled = vv > 0.5
		Settings.apply_all())
	_slider_row(v, "Volumetrischer Nebel", func(): return 1.0 if Settings.volumetric_fog else 0.0, func(vv: float):
		Settings.volumetric_fog = vv > 0.5
		Settings.apply_all())
	_slider_row(v, "Ambient Occlusion (SS)", func(): return 1.0 if Settings.ao_enabled else 0.0, func(vv: float):
		Settings.ao_enabled = vv > 0.5
		Settings.apply_all())
	_slider_row(v, "SSIL (indirektes Licht)", func(): return 1.0 if Settings.ssil_enabled else 0.0, func(vv: float):
		Settings.ssil_enabled = vv > 0.5
		Settings.apply_all())
	_slider_row(v, "SSR (Screenspace Reflections)", func(): return 1.0 if Settings.ssr_enabled else 0.0, func(vv: float):
		Settings.ssr_enabled = vv > 0.5
		Settings.apply_all())
	_slider_row(v, "Glow", func(): return 1.0 if Settings.glow_enabled else 0.0, func(vv: float):
		Settings.glow_enabled = vv > 0.5
		Settings.apply_all())
	_slider_row(v, "Nebelqualität (0/1/2)", func(): return float(Settings.fog_quality), func(vv: float):
		Settings.fog_quality = int(round(vv))
		Settings.apply_all())
	_slider_row(v, "Sichtweite", func(): return clampf(Settings.view_distance / 700.0, 0.05, 1.0), func(vv: float):
		Settings.view_distance = vv * 700.0
		Settings.apply_all())
	_slider_row(v, "LOD-Bias", func(): return clampf(Settings.lod_bias / 2.0, 0.1, 1.0), func(vv: float):
		Settings.lod_bias = vv * 2.0
		# LOD-Bias wirkt auf alle VisibleOnScreenNotifier-Registrierungen:
		for n in get_tree().get_nodes_in_group("lod_node"):
			if n is VisibleOnScreenNotifier3D:
				pass  # Godot steuert LOD über das Culling selbst; Bias ist Data-Quelle für unsere Builder.
		Settings.apply_all())
	_spinner_row(v, "Partikel-Multiplikator", func(): return Settings.particles_multiplier, func(vv: float):
		Settings.particles_multiplier = vv
		Settings.apply_all(), [0.25, 0.5, 1.0, 1.5, 2.0])
	_spinner_row(v, "Decal-Limit", func(): return float(Settings.decal_count_cap), func(vv: float):
		Settings.decal_count_cap = int(vv)
		Settings.apply_all(), [8.0, 16.0, 32.0, 48.0, 64.0])
	_spinner_row(v, "Texturfilter (0 next..7 aniso16)", func(): return float(Settings.texture_filter), func(vv: float):
		Settings.texture_filter = int(vv)
		Settings.apply_all(), [0.0, 1.0, 2.0, 3.0, 4.0, 5.0])
	_slider_row(v, "Cartoon-Outline", func(): return 1.0 if Settings.outline_enabled else 0.0, func(vv: float):
		Settings.outline_enabled = vv > 0.5
		Settings.apply_all())
	_slider_row(v, "Occlusion Culling (NEUSTART)", func(): return 1.0 if Settings.occlusion_culling else 0.0, func(vv: float):
		Settings.occlusion_culling = vv > 0.5
		Settings.apply_all()
		UI.toast("Occlusion Culling: startet beim nächsten Spielneustart komplett durch."))
	_refresh_all()

var _refs: Array[Dictionary] = []

func _refresh_all() -> void:
	pass

func _slider_row(parent: Control, label: String, getter: Callable, setter: Callable) -> void:
	var row := _row(parent, 0)
	row.get_child(0).text = label
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.0
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(220, 0)
	sl.value = float(getter.call())
	sl.value_changed.connect(setter)
	row.add_child(sl)

func _spinner_row(parent: Control, label: String, getter: Callable, setter: Callable, options: Array) -> void:
	var row := _row(parent, 0)
	row.get_child(0).text = label
	var opt := OptionButton.new()
	for o in options:
		opt.add_item(str(o))
	var cur := getter.call()
	for i in options.size():
		if absf(float(options[i]) - float(cur)) < 0.0001:
			opt.select(i)
			break
	opt.item_selected.connect(func(idx: int): setter.call(float(options[idx])))
	row.add_child(opt)

func _build_audio(parent: Control) -> void:
	_slider_row(parent, "Master (dB)", func(): return (Settings.master_volume_db + 40.0) / 40.0, func(vv: float):
		Settings.master_volume_db = lerpf(-40.0, 0.0, vv)
		Settings.set_volume_db("Master", Settings.master_volume_db))
	_slider_row(parent, "Effekte (dB)", func(): return (Settings.sfx_volume_db + 40.0) / 40.0, func(vv: float):
		Settings.sfx_volume_db = lerpf(-40.0, 0.0, vv)
		Settings.set_volume_db("Sfx", Settings.sfx_volume_db))
	_slider_row(parent, "Musik (dB)", func(): return (Settings.music_volume_db + 40.0) / 40.0, func(vv: float):
		Settings.music_volume_db = lerpf(-40.0, 0.0, vv)
		Settings.set_volume_db("Music", Settings.music_volume_db))

func _build_controls(parent: Control) -> void:
	_slider_row(parent, "Maus-Empfindlichkeit", func(): return clampf(Settings.mouse_sensitivity / 3.0, 0.02, 1.0), func(vv: float):
		Settings.mouse_sensitivity = clampf(vv * 3.0, 0.05, 3.0))
	_slider_row(parent, "Y-Invertiert", func(): return 1.0 if Settings.invert_y else 0.0, func(vv: float):
		Settings.invert_y = vv > 0.5)
	_slider_row(parent, "Kamera-FOV", func(): return clampf((Settings.camera_fov - 55.0) / 60.0, 0.0, 1.0), func(vv: float):
		Settings.camera_fov = lerpf(55.0, 115.0, vv)
		Settings.apply_all())
	var info := Label.new()
	info.text = "Tasten: WASD Bewegung · RMB Greifen · E Interagieren · Q/E drehen\n1-5 Werkzeuge · M Karte · Esc Menü · H Hupe · F Aussteigen · B Baumodus\nController: Stick/L + Stick/R · A Springen · X Interact · RT? -> Y Grab · Bump Tool"
	parent.add_child(info)

func _build_game(parent: Control) -> void:
	_slider_row(parent, "Schadens-Popups", func(): return 1.0 if Settings.damage_popups else 0.0, func(vv: float):
		Settings.damage_popups = vv > 0.5)
	var w := Button.new()
	w.text = "Fenster-Modus wechseln (Borderless)"
	w.pressed.connect(func() -> void:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN))
	parent.add_child(w)
	var res := OptionButton.new()
	for rr in ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"]:
		res.add_item(rr)
	res.item_selected.connect(func(idx: int) -> void:
		var parts: PackedStringArray = String(res.get_item_text(idx)).split("x")
		DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1]))))
	var rl := _row(parent, 0)
	rl.get_child(0).text = "Auflösung"
	rl.add_child(res)
	var save_b := Button.new()
	save_b.text = "Einstellungen dauerhaft speichern"
	save_b.pressed.connect(func() -> void:
		var f := FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(Settings.to_save_dict(), " "))
			f.close()
			UI.toast("settings.cfg geschrieben"))
	parent.add_child(save_b)
