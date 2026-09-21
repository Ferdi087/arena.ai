extends Node
class_name BuildMode
## HQ-Baumodus (#14/#15): 0.5m-Grid, Ghost-Vorschau, Rotation (R), Fein-Nudge
## (Shift+Pfeile via Mausebene: Alt = freies Snap alle 0.05m), Entfernen (Rechts-
## klick), Kosten via BuildPieceData, Qualität -> Company (Reputation-Drift #16),
## Persistenz über "hq_build" Save-Sektion des HQ-Szene.
##
## Zustand ist REINE DATENLISTE (cells) + Kind-Instanzen – kein Szenen-Getakel.

const CELL := 0.5
const PLANES := 3  # EG, 1. OG, 2. OG

signal build_state_changed(active: bool)
signal pieces_changed(count: int, quality: float)

var active: bool = false
var world: WorldRoot = null
var current_piece: BuildPieceData = null
var floor_level: int = 0
var rotation_step: int = 0          # 0..3
var nudge: Vector2 = Vector2.ZERO   # Feinverschiebung in m (nur bei Alt)
var pieces: Array[Dictionary] = []  # {id, cell, rot, floor, nudge}
var ghost: Node3D = null
var ghost_material: StandardMaterial3D = null
var _cam: Camera3D = null
var _last_mouse: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_physics_process(false)
	_build_ghost()

func _build_ghost() -> void:
	ghost = Node3D.new()
	ghost.name = "BuildGhost"
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(CELL * 2, 2.6, CELL * 2)
	mi.mesh = bm
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.albedo_color = Color(0.3, 0.9, 0.4, 0.4)
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = ghost_material
	ghost.add_child(mi)
	ghost.visible = false
	world.add_child(ghost)

func bind(w: WorldRoot) -> void:
	world = w
	_build_ghost() if ghost.get_child_count() == 0 else null

func toggle() -> void:
	active = not active
	build_state_changed.emit(active)
	ghost.visible = false
	if active:
		set_current(Content.get_build_piece(&"wall_basic"))
		UI.open_palette()
		_cam = world.get_viewport().get_camera_3d()
		UI.hud_hint("BAUMODUS: Linksklick=Setzen | RMB=Entfernen | R=Drehen | 1-9 Kategorie")
	else:
		UI.close_palette()
		_recount_quality()

func set_current(piece: BuildPieceData) -> void:
	current_piece = piece
	if piece != null:
		var mi := ghost.get_child(0) as MeshInstance3D
		mi.mesh = _ghost_mesh(piece)
		ghost.visible = active

func _ghost_mesh(piece: BuildPieceData) -> Mesh:
	var bm := BoxMesh.new()
	match int(piece.kind):
		BuildPieceData.Kind.FLOOR, BuildPieceData.Kind.CEILING:
			bm.size = Vector3(piece.grid_footprint.x * CELL, 0.1, piece.grid_footprint.y * CELL)
		BuildPieceData.Kind.STAIR:
			bm.size = Vector3(piece.grid_footprint.x * CELL, piece.height_m, piece.grid_footprint.y * CELL * 0.5)
		_:
			bm.size = Vector3(maxf(piece.grid_footprint.x * CELL, 0.4), piece.height_m, maxf(0.12, piece.grid_footprint.y * CELL * 0.08))
	return bm

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_toggle"):
		if world != null:
			toggle()
		return
	if not active:
		return
	if event is InputEventMouseMotion:
		_update_ghost_at_mouse(event.position)
	elif event is InputEventMouseButton:
		_last_mouse = event.position
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_place()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_try_remove_at_mouse(event.position)
	elif event.is_action_pressed("build_rotate"):
		rotation_step = (rotation_step + 1) % maxi(current_piece.rotation_snaps if current_piece != null else 4, 1)

func _plane_y() -> float:
	return float(floor_level) * 2.9

func _update_ghost_at_mouse(mp: Vector2) -> void:
	if _cam == null or current_piece == null:
		return
	var from := _cam.project_ray_origin(mp)
	var dir := _cam.project_ray_normal(mp)
	var hit := _ray_to_plane(from, dir, _plane_y())
	if hit == Vector3.INF:
		return
	var cell := _snap_cell(hit)
	var rot := rotation_step * (TAU / float(maxi(current_piece.rotation_snaps, 4)))
	var pos := _cell_center(cell, floor_level) + Vector3(nudge.x, 0, nudge.y)
	ghost.global_position = pos
	ghost.rotation.y = rot

func _ray_to_plane(from: Vector3, dir: Vector3, y: float) -> Vector3:
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := (y - from.y) / dir.y
	if t < 0.0:
		return Vector3.INF
	return from + dir * t

func _snap_cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floorf((p.x + 0.0) / CELL)), int(floorf((p.z + 0.0) / CELL)))

func _cell_center(cell: Vector2i, floor_: int) -> Vector3:
	return Vector3((float(cell.x) + 0.5) * CELL, float(floor_) * 2.9 + 0.05, (float(cell.y) + 0.5) * CELL)

func _try_place() -> void:
	if current_piece == null or _cam == null:
		return
	var hit := _ray_to_plane(_cam.project_ray_origin(_last_mouse), _cam.project_ray_normal(_last_mouse), _plane_y())
	if hit == Vector3.INF:
		return
	var cell := _snap_cell(hit)
	if _occupied(cell, floor_level):
		UI.toast("Feld belegt")
		return
	if not Company.try_spend(current_piece.cost, "Baumodus"):
		return
	var entry := {
		"id": String(current_piece.id),
		"cell": [cell.x, cell.y],
		"rot": rotation_step,
		"floor": floor_level,
		"nudge": [nudge.x, nudge.y],
	}
	pieces.append(entry)
	_instantiate(entry, false)
	_recount_quality()
	Sfx.play_world(hit, &"build_hammer", -8.0)
	EventBus.build_piece_placed.emit(current_piece, cell)
	Saves.mark_dirty()

func _try_remove_at_mouse(mp: Vector2) -> void:
	if _cam == null:
		return
	var hit := _ray_to_plane(_cam.project_ray_origin(mp), _cam.project_ray_normal(mp), _plane_y())
	if hit == Vector3.INF:
		return
	var cell := _snap_cell(hit)
	for i in range(pieces.size() - 1, -1, -1):
		var e: Dictionary = pieces[i]
		var ec := Vector2i(int(e["cell"][0]), int(e["cell"][1]))
		if ec == cell and int(e.get("floor", 0)) == floor_level:
			var refund: float = 0.0
			var bd: BuildPieceData = Content.get_build_piece(StringName(String(e["id"])))
			if bd != null:
				refund = bd.cost * 0.5
			Company.add_money(refund, "Rückbau")
			pieces.remove_at(i)
			# Visual-Knoten finden (Name Muster)
			var nodes := get_tree().get_nodes_in_group("hq_pieces")
			for n in nodes:
				if n.has_meta("piece_index") and int(n.get_meta("piece_index")) == i:
					n.queue_free()
			_reindex()
			_recount_quality()
			Saves.mark_dirty()
			return

func _reindex() -> void:
	var nodes := get_tree().get_nodes_in_group("hq_pieces")
	for n in nodes:
		if n.has_meta("piece_index"):
			var idx := int(n.get_meta("piece_index"))
			if idx >= pieces.size():
				n.queue_free()
			else:
				n.set_meta("piece_index", idx)

func _occupied(cell: Vector2i, floor_: int) -> bool:
	for e in pieces:
		if Vector2i(int(e["cell"][0]), int(e["cell"][1])) == cell and int(e.get("floor", 0)) == floor_:
			return true
	return false

func _instantiate(entry: Dictionary, restore: bool) -> void:
	var bd: BuildPieceData = Content.get_build_piece(StringName(String(entry["id"])))
	if bd == null:
		return
	var node := Node3D.new()
	node.add_to_group("hq_pieces")
	node.name = "Piece_%s" % String(entry["id"])
	var cell := Vector2i(int(entry["cell"][0]), int(entry["cell"][1]))
	var nud: Array = entry.get("nudge", [0, 0])
	node.position = _cell_center(cell, int(entry.get("floor", 0))) + Vector3(float(nud[0]), 0, float(nud[1]))
	node.rotation.y = float(entry.get("rot", 0)) * (TAU / float(maxi(bd.rotation_snaps, 4)))
	var mi := MeshInstance3D.new()
	mi.mesh = _ghost_mesh(bd)
	var style := get_node_or_null(^"/root/Style") as StyleService
	var is_glass := int(bd.kind) == int(BuildPieceData.Kind.WINDOW) or int(bd.kind) == int(BuildPieceData.Kind.DOOR)
	var col := Color(0.5, 0.8, 0.9) if is_glass else Color(0.62, 0.55, 0.45)
	if style != null:
		mi.material_override = style.get_flat_material(bd.id, col, 0.8)
	node.add_child(mi)
	# statischer Kollisionsblocker (Bauen spürbar machen)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var gmesh := _ghost_mesh(bd)
	if gmesh is BoxMesh:
		box.size = (gmesh as BoxMesh).size
	cs.shape = box
	body.add_child(cs)
	node.add_child(body)
	if bd.kind == BuildPieceData.Kind.LIGHT:
		var light := OmniLight3D.new()
		light.omni_range = 9.0
		light.position = Vector3(0, -0.4, 0)
		node.add_child(light)
	node.set_meta("piece_index", pieces.find(entry))
	world.add_child(node)

func quality_score() -> float:
	var s := 0.0
	for e in pieces:
		var bd: BuildPieceData = Content.get_build_piece(StringName(String(e["id"])))
		if bd != null:
			s += bd.hq_quality_score
	return s

func _recount_quality() -> void:
	var q := quality_score()
	EventBus.hq_quality_changed.emit(q)
	pieces_changed.emit(pieces.size(), q)
	# HQ-Qualität => Reputations-Drift (#16), sanft gekappt:
	Company.apply_hq_quality_drift(clampf(q / 120.0, -2.0, 3.5))

# ------------------------------------------------------------ Save/Restore --

func save_to_dict() -> Dictionary:
	return {"pieces": pieces, "floor": floor_level}

func apply_save_data(d: Dictionary) -> void:
	for old in get_tree().get_nodes_in_group("hq_pieces"):
		old.queue_free()
	pieces.clear()
	var raw: Array = d.get("pieces", [])
	for e in raw:
		pieces.append(e)
		_instantiate(e, true)
	_recount_quality()

func set_floor(f: int) -> void:
	floor_level = clampi(f, 0, PLANES - 1)
