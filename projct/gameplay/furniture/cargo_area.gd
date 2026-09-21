extends Node3D
class_name CargoArea
## Ladevolumen des Trucks (#82): erkennt reingetragene Möbel (Hold über Volume),
## verankert sie an Anchor-Slots (Freeze = "physikalisch festgezurrt"), zählt
## Strap-Level und wirft ungesicherte Last bei G-Kräften wieder raus.
##
## Wichtig: Kein "Inventar-Sog" – das Möbel STÜCK bleibt dasselbe Objekt; der
## Truck wird nur sein Parent. Position = Anchor, Physik = freeze. Reversibel.

const ANCHOR_GRID := Vector2(2, 3)   # 2 quer x 3 längs Slots
const STRAP_HOLD_G := 7.5             # m/s² die ein Gurt hält

var vehicle: VehicleController = null
var data: VehicleData = null
var anchors: Array[Transform3D] = []
var _occupied: Dictionary[RID, int] = {}  # body rid -> anchor index

func bind(v: VehicleController, vdata: VehicleData) -> void:
	vehicle = v
	data = vdata
	_rebuild_anchors()

func _rebuild_anchors() -> void:
	anchors.clear()
	if data == null:
		return
	var size := data.cargo_area_size
	var off := data.cargo_area_offset
	var slots_x := int(ANCHOR_GRID.x)
	var slots_z := int(ANCHOR_GRID.y)
	for ix in slots_x:
		for iz in slots_z:
			var lx := (float(ix) - (slots_x - 1) * 0.5) * (size.x / float(slots_x))
			var lz := (float(iz) - (slots_z - 1) * 0.5) * (size.z / float(slots_z))
			var t := Transform3D(Basis.IDENTITY, Vector3(off.x + lx, off.y + size.y * 0.34, off.z + lz))
			anchors.append(t)

func in_cargo_volume(global_pos: Vector3) -> bool:
	if vehicle == null or data == null:
		return false
	var local := vehicle.global_transform.affine_inverse().xform(global_pos)
	var c := data.cargo_area_offset
	var s := data.cargo_area_size
	return absf(local.x - c.x) <= s.x * 0.62 and local.z > c.z - s.z * 0.6 and local.z < c.z + s.z * 0.62 and local.y > c.y - 0.4 and local.y < c.y + s.y + 0.8

func free_anchor_for(body: FurnitureBody) -> int:
	if anchors.is_empty():
		return -1
	var he := 0.6
	if body.data != null:
		he = body.data.half_extents.x
	# Breite > halbe Slotbreite -> 2 Slots blockiert (grobe Näherung: Index-Paare)
	var needed := 1 if he < 0.55 else 2
	for i in anchors.size():
		if needed > 1 and i + 1 >= anchors.size():
			break
		if not _occupied.values().has(i) and (needed == 1 or not _occupied.values().has(i + 1)):
			return i
	return -1

func try_load(body: FurnitureBody) -> bool:
	if vehicle == null or body == null:
		return false
	if vehicle.overladen():
		UI.toast("Truck ist überladen – Last verteilen/abarbeiten!")
		return false
	var idx := free_anchor_for(body)
	if idx < 0:
		UI.toast("Kein freier Stellplatz auf der Pritsche")
		return false
	var anchor := anchor_world(idx)
	body.lock_in_cargo(anchor)
	body.reparent(vehicle)
	_occupied[body.get_rid()] = idx
	vehicle.add_cargo_item(body)
	Sfx.play_world(body.global_position, &"cargo_lock", -6.0)
	return true

func unload(body: FurnitureBody) -> void:
	if body == null:
		return
	var world := get_tree().get_first_node_in_group("world")
	_occupied.erase(body.get_rid())
	vehicle.remove_cargo_item(body)
	body.reparent(world if world != null else get_tree().current_scene, true)
	body.unlock_from_cargo()
	body.global_position = body.global_position + Vector3(0, 0.1, 0)
	body.velocity = Vector3.ZERO

func eject_unsecured(body: FurnitureBody) -> void:
	## Von VehicleController gerufen: Last rutscht runter (Chaos-Moment #88).
	_occupied.erase(body.get_rid())
	vehicle.remove_cargo_item(body)
	var world := get_tree().get_first_node_in_group("world")
	body.reparent(world if world != null else get_tree().current_scene, true)
	body.unlock_from_cargo()
	var dir := (body.global_position - vehicle.global_position)
	dir.y = 0.4
	body.velocity = vehicle.linear_velocity + dir.normalized() * 3.0
	body.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	if body.has_meta("furniture_data"):
		var dmg := body.get_node_or_null("Damage") as DamageComponent
		if dmg != null:
			dmg.apply_tool_damage(18.0, body.global_position, &"fall")

func anchor_world(idx: int) -> Transform3D:
	var t := anchors[idx]
	return vehicle.global_transform * t

func strap_level(body: FurnitureBody) -> int:
	var v := body.get_meta("straps") if body.has_meta("straps") else 0
	return int(v)

func set_straps(body: FurnitureBody, count: int) -> void:
	body.set_meta("straps", clampi(count, 0, 2))
	UI.hint_changed("Gurte: %d/2" % clampi(count, 0, 2))

func held_strongly(body: FurnitureBody, accel: float) -> bool:
	return strap_level(body) * STRAP_HOLD_G >= accel

func debug_info() -> String:
	return "cargo=%d/%d anchors" % [_occupied.size(), anchors.size()]
