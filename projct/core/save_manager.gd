extends Node
## Save Manager (Autoload "Saves") – versioniertes, robustes Save-System.
##
## Architektur (#72/#113):
##   user://saves/slot_<n>.json (+ .bak Backup, atomar via tmp+rename)
##   { "save_version": 1, "created_utc": ..., "sections": { ... } }
## Jeder Abschnitt wird von einem Contributor serialisiert (duck-typed:
## save_to_dict()/load_from_dict()) – Saveable-Komponenten registrieren sich.
## Migration: Migrations-Kette 1->2->3... vor dem Parsen.
## Beschädigtes Save -> .bak-Versuch -> EventBus.load_failed (kein Crash, #102).

const SAVE_VERSION := 1
const SAVE_DIR := "user://saves"
const MAX_SLOTS := 3

var active_slot: int = 0
var _contributors: Array[Node] = []
var _dirty: bool = false

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	# Contributor = jeder Node mit save_key + save_to_dict()/load_from_dict().
	register_contributor(Company)
	register_contributor(Characters)
	register_contributor(Missions)
	# Autosave alle 3 Minuten, nur wenn dirty (kein Blind-Write, #74).
	var t := Timer.new()
	t.wait_time = 180.0
	t.autostart = true
	t.one_shot = false
	t.connect("timeout", _autosave)
	add_child(t)

func register_contributor(node: Node) -> void:
	if node == null:
		return
	if not _contributors.has(node):
		_contributors.append(node)

func unregister_contributor(node: Node) -> void:
	_contributors.erase(node)

func mark_dirty() -> void:
	_dirty = true

func _autosave() -> void:
	if not _dirty or Game.state != Game.AppState.IN_GAME:
		return
	_dirty = false
	save_to_slot(active_slot)
	EventBus.save_completed.emit(active_slot, _slot_path(active_slot))

# -------------------------------------------------------------- Serialisierung

func build_save_dict() -> Dictionary:
	var sections := {}
	for c in _contributors:
		if is_instance_valid(c) and c.has_method("save_to_dict"):
			var key: String = c.get("save_key") if c.get("save_key") != null else c.name
			sections[key] = c.save_to_dict()
	return {
		"save_version": SAVE_VERSION,
		"created_utc": Time.get_datetime_string_from_system(true, true),
		"game_seed": Game.game_seed,
		"sections": sections,
	}

func apply_save_dict(raw: Dictionary) -> void:
	var migrated := migrate(raw)
	var sections: Dictionary = migrated.get("sections", {})
	for c in _contributors:
		if is_instance_valid(c) and c.has_method("load_from_dict"):
			var key: String = c.get("save_key") if c.get("save_key") != null else c.name
			var sub: Dictionary = sections.get(key, {})
			if not sub.is_empty():
				c.load_from_dict(sub)
	# Settings global anwenden
	var settings_section: Dictionary = sections.get("settings", {})
	if not settings_section.is_empty():
		Settings.from_save_dict(settings_section)
	if migrated.get("game_seed", 0) != 0:
		seed(int(migrated["game_seed"]))

# -------------------------------------------------------- Migration (vN->vN+1)

static func migrate(raw: Dictionary) -> Dictionary:
	var data := raw.duplicate(true)
	var v := int(data.get("save_version", 1))
	while v < SAVE_VERSION:
		match v:
			1:
				# Beispiel-Hook: v1 -> v2 (z. B. Paint-Format quadrants->atlas).
				# Aktuell identisch – Kette bleibt für echte Migrationen stehen.
				v = 2
			_:
				push_error("Saves: keine Migration für v%d" % v)
				break
	data["save_version"] = SAVE_VERSION
	return data

# ------------------------------------------------------------------- Slot-IO --

func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]

func save_to_slot(slot: int) -> Error:
	active_slot = slot
	var data := build_save_dict()
	# Settings immer mitschreiben
	data["sections"]["settings"] = Settings.to_save_dict()
	var json_text := JSON.stringify(data, "  ")
	var tmp_path := _slot_path(slot) + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		var err := _open_err()
		EventBus.save_failed.emit(slot, "Datei konnte nicht geöffnet werden (%s)" % error_string(err))
		return err
	f.store_string(json_text)
	f.close()
	var final_path := _slot_path(slot)
	if FileAccess.file_exists(final_path):
		# Backup der alten Version
		var old := FileAccess.get_file_as_bytes(final_path)
		var bf := FileAccess.open(final_path + ".bak", FileAccess.WRITE)
		if bf != null:
			bf.store_buffer(old)
			bf.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(final_path))
	var rr := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(final_path))
	if rr != OK:
		# Fallback: direkt reinschreiben (Plattform ohne rename-Rechte)
		var f2 := FileAccess.open(final_path, FileAccess.WRITE)
		if f2 != null:
			f2.store_string(json_text)
			f2.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
	EventBus.save_completed.emit(slot, final_path)
	return OK

func load_slot(slot: int) -> bool:
	active_slot = slot
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		if not FileAccess.file_exists(path + ".bak"):
			EventBus.load_failed.emit(slot, "kein Save in Slot %d" % slot)
			return false
		path += ".bak"
		push_warning("Saves: Hauptdatei fehlt – nutze .bak")
	var text := FileAccess.get_file_as_string(path)
	var parsed := JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		# Hauptdatei korrupt? Backup versuchen.
		if FileAccess.file_exists(_slot_path(slot) + ".bak"):
			var alt := FileAccess.get_file_as_string(_slot_path(slot) + ".bak")
			parsed = JSON.parse_string(alt)
		if typeof(parsed) != TYPE_DICTIONARY:
			EventBus.load_failed.emit(slot, "Savegame ist kein gültiges JSON – Backup vorhanden?")
			return false
	var raw: Dictionary = parsed
	# Unbekannte ZUKUNFTS-Version: nicht blind laden, aber auch nicht crashen.
	if int(raw.get("save_version", 0)) > SAVE_VERSION:
		push_warning("Saves: Save v%d ist neuer als Engine v%d –teilweise Felder können fehlen." % [int(raw["save_version"]), SAVE_VERSION])
	apply_save_dict(raw)
	EventBus.load_completed.emit(slot)
	return true

func delete_slot(slot: int) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var p := _slot_path(slot) + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func slot_info(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed := JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"corrupt": true}
	var raw: Dictionary = parsed
	var company_sec: Dictionary = raw.get("sections", {}).get("company", {})
	return {
		"save_version": int(raw.get("save_version", 0)),
		"created_utc": String(raw.get("created_utc", "?")),
		"company": String(company_sec.get("name", "–")),
		"money": float(company_sec.get("money", 0)),
		"reputation": float(company_sec.get("reputation", 0)),
		"corrupt": false,
	}

func _open_err() -> Error:
	return FileAccess.get_open_error()
