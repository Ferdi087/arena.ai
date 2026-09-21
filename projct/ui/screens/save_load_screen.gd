extends BaseScreen
class_name SaveLoadScreen
## Mehrere Spielstände, Laden/Speichern/Löschen mit Info-Karten (#52/#72).

var mode_save: bool = true

func _init(is_save: bool = true) -> void:
	mode_save = is_save

func _ready() -> void:
	title = "SPIEL STAND" if mode_save else "STAND LADEN"
	overlay_enum = UI.Overlay.SAVE_LOAD
	super()

func _panel_size() -> Vector2:
	return Vector2(720, 520)

func build_body(body: Control) -> void:
	for slot in Saves.MAX_SLOTS:
		var info: Dictionary = Saves.slot_info(slot)
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, 72)
		if info.is_empty():
			row.text = "Slot %d — frei" % (slot + 1)
		elif bool(info.get("corrupt", false)):
			row.text = "Slot %d — ⚠ BESCHÄDIGT (Backup versuchen)" % (slot + 1)
		else:
			row.text = "Slot %d — %s · %.0f € · Ruf %.0f · %s" % [
				slot + 1,
				String(info.get("company", "–")),
				float(info.get("money", 0.0)),
				float(info.get("reputation", 0.0)),
				String(info.get("created_utc", "?")),
			]
		var s := slot
		if mode_save:
			row.pressed.connect(_save_slot.bind(s))
		else:
			row.pressed.connect(_load_slot.bind(s))
		body.add_child(row)
		if not info.is_empty() and not bool(info.get("corrupt", false)):
			var del := Button.new()
			del.text = "Slot %d löschen" % (s + 1)
			del.modulate = Color(1, 0.6, 0.6)
			del.pressed.connect(func() -> void:
				Saves.delete_slot(s)
				refresh())
			body.add_child(del)

func _save_slot(s: int) -> void:
	var err := Saves.save_to_slot(s)
	if err == OK:
		Sfx.ui_confirm()
		UI.toast("Slot %d gespeichert ✔" % (s + 1))
		refresh()

func _load_slot(s: int) -> void:
	if Saves.load_slot(s):
		Sfx.ui_confirm()
		Game.change_state(Game.AppState.LOADING)
		Scenes.change_scene("res://scenes/world/hq.tscn", _after_load)
		UI.close(UI.Overlay.SAVE_LOAD)
	else:
		UI.toast("Laden fehlgeschlagen – Datei defekt?")

func _after_load() -> void:
	Game.change_state(Game.AppState.IN_GAME)

func refresh() -> void:
	var parent := get_node_or_null("Panel/Body")
	if parent != null:
		for c in parent.get_children():
			c.queue_free()
		build_body(parent)
