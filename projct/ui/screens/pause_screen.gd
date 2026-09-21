extends BaseScreen
class_name PauseScreen

func _ready() -> void:
	title = "PAUSE – %s" % Company.data.company_name
	overlay_enum = UI.Overlay.PAUSE
	super()

func _panel_size() -> Vector2:
	return Vector2(460, 420)

func build_body(body: Control) -> void:
	_btn(body, "Weiterspielen", func() -> void: UI.close(UI.Overlay.PAUSE))
	_btn(body, "Speichern (Schnell)", _save)
	_btn(body, "Einstellungen", func() -> void: UI.open(UI.Overlay.SETTINGS))
	_btn(body, "Charakter anpassen", func() -> void: UI.toast("Im HQ-Baumodus/Creator – Slice: Menü 'Charakter'"))
	_btn(body, "Hauptmenü", func() -> void:
		UI.close(UI.Overlay.PAUSE)
		Game.quit_to_menu())
	_btn(body, "Beenden", func() -> void: Game.quit_game())

func _btn(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(cb)
	parent.add_child(b)

func _save() -> void:
	var err := Saves.save_to_slot(Saves.active_slot)
	if err == OK:
		Sfx.ui_confirm()
		UI.toast("Gespeichert ✔")
	else:
		UI.toast("Speichern fehlgeschlagen – Log prüfen")
