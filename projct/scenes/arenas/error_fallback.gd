extends Control
## Absturz-Fallback-Szene: wird geladen, wenn eine Zielszene fehlt/kaputt ist
## (scene_manager.gd). Zeigt Fehler + Neustart-Buttons – kein Black-Screen.

var last_error: String = ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.04, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var v := VBoxContainer.new()
	c.add_child(v)
	var t := Label.new()
	t.text = "SCENE KONNTE NICHT GELADEN WERDEN"
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	v.add_child(t)
	var e := Label.new()
	e.text = last_error if not last_error.is_empty() else "Letzte Zielszene war nicht vorhanden oder fehlerhaft.\n\nMögliche Ursachen:\n · .tscn-Pfad Tippfehler\n · Skript-Compile-Fehler (Konsole prüfen)\n · fehlende Resource"
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.custom_minimum_size = Vector2(560, 0)
	v.add_child(e)
	var retry := Button.new()
	retry.text = "Hauptmenü neu laden"
	retry.pressed.connect(func() -> void:
		get_tree().paused = false
		Game.change_state(Game.AppState.MAIN_MENU)
		get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn"))
	v.add_child(retry)
	var quit_b := Button.new()
	quit_b.text = "Beenden"
	quit_b.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(quit_b)
