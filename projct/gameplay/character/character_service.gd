extends Node
## Character Service (Autoload "Characters") – hält CharacterData + Paint und
## vermittelt sie an alle Instanzen (Creator-Preview, Player, Remote-Player,
## Hireling-Look). Autoload-Begründung: Aussehen muss Menü <-> Welt <-> Save
## überleben und wird netzwerk-seitig über Net broadcast.
##
## Paint-Persistenz: 512²-Quadranten-PNG base64 im Save (kompakt, #9).

const PAINT_DIR := "user://saves/paint"

var current_character: CharacterData = CharacterData.new()
var equipped_accessories: Array[StringName] = []
var _dirty_paint: bool = false

signal character_applied(c: CharacterData)
signal character_data_changed

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(PAINT_DIR)
	EventBus.paint_stroke_finished.connect(_on_stroke)

var save_key: String = "character"

func set_character(c: CharacterData) -> void:
	current_character = c
	character_data_changed.emit()
	character_applied.emit(c)

func equip_cosmetic(id: StringName, silent: bool = false) -> void:
	var cos: CosmeticData = Content.get_cosmetic(id)
	if cos == null:
		push_warning("Characters: unbekanntes Cosmetic %s" % id)
		return
	if not cos.is_unlocked_for(Company):
		if not silent:
			UI.toast("Gesperrt: %s" % cos.display_name)
		return
	# Slot-Regel: pro Slot max 1
	for existing in equipped_accessories.duplicate():
		var ec: CosmeticData = Content.get_cosmetic(existing)
		if ec != null and ec.slot == cos.slot:
			equipped_accessories.erase(existing)
	if not equipped_accessories.has(id):
		equipped_accessories.append(id)
	current_character.equipped = PackedStringArray(_to_str(equipped_accessories))
	character_applied.emit(current_character)
	if not silent:
		EventBus.accessory_equipped.emit(&"slot_%d" % cos.slot, cos)
		Saves.mark_dirty()

func unequip_slot(slot: CosmeticData.Slot) -> void:
	for existing in equipped_accessories.duplicate():
		var ec: CosmeticData = Content.get_cosmetic(existing)
		if ec != null and ec.slot == slot:
			equipped_accessories.erase(existing)
	current_character.equipped = PackedStringArray(_to_str(equipped_accessories))
	character_applied.emit(current_character)
	Saves.mark_dirty()

func _to_str(arr: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for e in arr:
		out.append(String(e))
	return out

func apply_to_player(player: Player) -> void:
	var visual := player.get_visual()
	if visual == null:
		return
	visual.data = current_character
	visual.apply_morphs()
	var ps := visual.get_paint_surface()
	if ps != null and _pending_paint_b64 != "":
		ps.from_base64(_pending_paint_b64)
		_pending_paint_b64 = ""

var _pending_paint_b64: String = ""

# ------------------------------------------------------------------- Paint --

func paint_on_character(player: Player, hit_world: Vector3, normal_world: Vector3, params: Dictionary) -> Dictionary:
	var visual := player.get_visual()
	if visual == null:
		return {}
	var ps := visual.get_paint_surface()
	if ps == null:
		return {}
	var local_hit := visual.global_transform.affine_inverse().xform(hit_world)
	var local_nrm := visual.global_transform.basis.inverse().xform(normal_world)
	var record := ps.stroke_at_world(local_hit, local_nrm, params)
	if not record.is_empty():
		_dirty_paint = true
		Saves.mark_dirty()
	return record

func replay_character_stroke(record: Dictionary) -> void:
	for player in get_tree().get_nodes_in_group("players"):
		var v := (player as Player).get_visual()
		if v != null:
			var ps := v.get_paint_surface()
			if ps != null:
				ps.replay_stroke(record)
				ps.commit_frame()

func _on_stroke(_target: StringName, _quad: int) -> void:
	_dirty_paint = true

func flush_paint() -> void:
	if not _dirty_paint:
		return
	_dirty_paint = false

# -------------------------------------------------------------------- Save --

func save_to_dict() -> Dictionary:
	var paint_b64 := ""
	for player in get_tree().get_nodes_in_group("players"):
		var v := (player as Player).get_visual()
		if v != null:
			var ps := v.get_paint_surface()
			if ps != null:
				paint_b64 = ps.to_base64()
				break
	return {
		"data": {
			"display_name": current_character.display_name,
			"height": current_character.height, "width": current_character.width,
			"belly": current_character.belly, "shoulder_width": current_character.shoulder_width,
			"head_size": current_character.head_size, "head_width": current_character.head_width,
			"arm_length": current_character.arm_length, "leg_length": current_character.leg_length,
			"hand_size": current_character.hand_size, "foot_size": current_character.foot_size,
			"neck_length": current_character.neck_length, "weight_class": current_character.weight_class,
			"skin_color": current_character.skin_color.to_html(),
			"shirt_color": current_character.shirt_color.to_html(),
			"pants_color": current_character.pants_color.to_html(),
			"equipped": _to_str(current_character.equipped),
		},
		"paint_b64": paint_b64,
	}

func load_from_dict(d: Dictionary) -> void:
	var c := CharacterData.new()
	var data: Dictionary = d.get("data", {})
	c.display_name = String(data.get("display_name", c.display_name))
	for prop in ["height", "width", "belly", "shoulder_width", "head_size", "head_width",
			"arm_length", "leg_length", "hand_size", "foot_size", "neck_length", "weight_class"]:
		if data.has(prop):
			c.set(prop, clampf(float(data[prop]), 0.0, 1.0))
	c.skin_color = Color(String(data.get("skin_color", "f5c79eff")))
	c.shirt_color = Color(String(data.get("shirt_color", "e64d40ff")))
	c.pants_color = Color(String(data.get("pants_color", "334773ff")))
	var eq: Array = data.get("equipped", [])
	equipped_accessories.clear()
	for e in eq:
		equipped_accessories.append(StringName(String(e)))
	c.equipped = PackedStringArray(_to_str(equipped_accessories))
	set_character(c)
	_pending_paint_b64 = String(d.get("paint_b64", ""))
	# Live an alle vorhandenen Spieler anwenden:
	for player in get_tree().get_nodes_in_group("players"):
		apply_to_player(player)
