extends WorldRoot
class_name HQRoot
## HQ-Welt: nutzt WorldRoot-Fundament + Baubetrieb + Computer + Garage +
## Hiring-Desk + Truck-Bay. Save-Sektion "hq" (BuildMode pieces).

var build_mode: BuildMode = null
var hire_desk: StaticBody3D = null
var garage_terminal: ComputerTerminal = null
var company_terminal: ComputerTerminal = null
var _hq_ready: bool = false

func _ready() -> void:
	# Base baut Environment/Ground/Units; wir ergänzen das HQ-Gebäude.
	_build_hq_shell()
	_place_terminals()
	super()
	_hq_ready = true

func _build_hq_shell() -> void:
	var style := get_node_or_null(^"/root/Style") as StyleService
	var hq := Node3D.new()
	hq.name = "HQ"
	add_child(hq)
	# Bodenplatte 20x14, Wände niedrig (Rempler-Optik), Dach offen (Decke folgt im Baumodus)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var fcs := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(20, 0.4, 14)
	fcs.shape = fbox
	fcs.position = Vector3(0, -0.2, 0)
	floor_body.add_child(fcs)
	var fmi := MeshInstance3D.new()
	var fbm := BoxMesh.new()
	fbm.size = Vector3(20, 0.4, 14)
	fmi.mesh = fbm
	if style != null:
		fmi.material_override = style.get_flat_material(&"hq_floor", Color(0.35, 0.32, 0.3), 0.9)
	floor_body.add_child(fmi)
	hq.add_child(floor_body)
	_walls(hq, style)
	# Baufeld-Raster sichtbar machen
	var grid := MeshInstance3D.new()
	var gridmesh := PlaneMesh.new()
	gridmesh.size = Vector2(19.9, 13.9)
	grid.mesh = gridmesh
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.albedo_color = Color(0.4, 0.9, 0.6, 0.05)
	grid.material_override = gmat
	grid.position = Vector3(0, 0.02, 0)
	hq.add_child(grid)

func _walls(parent: Node3D, style: StyleService) -> void:
	var wall_defs := [
		[Vector3(0, 1.3, -7), Vector3(20, 2.6, 0.3)],
		[Vector3(-10, 1.3, 0), Vector3(0.3, 2.6, 14)],
		[Vector3(10, 1.3, 0), Vector3(0.3, 2.6, 14)],
		[Vector3(-6.5, 1.3, 7), Vector3(7, 2.6, 0.3)],
		[Vector3(6.5, 1.3, 7), Vector3(7, 2.6, 0.3)],
	]
	for d in wall_defs:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = d[1]
		cs.shape = box
		body.add_child(cs)
		body.position = d[0]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = d[1]
		mi.mesh = bm
		if style != null:
			mi.material_override = style.get_flat_material(&"hq_wall", Color(0.72, 0.66, 0.55), 0.92)
		body.add_child(mi)
		parent.add_child(body)

func _place_terminals() -> void:
	company_terminal = ComputerTerminal.new()
	company_terminal.name = "CompanyTerminal"
	company_terminal.terminal_role = &"company"
	company_terminal.position = Vector3(-7.5, 1.1, -4.5)
	add_child(company_terminal)
	_desk_for(company_terminal)
	garage_terminal = ComputerTerminal.new()
	garage_terminal.name = "GarageTerminal"
	garage_terminal.terminal_role = &"garage"
	garage_terminal.position = Vector3(7.5, 1.1, -4.5)
	add_child(garage_terminal)
	_desk_for(garage_terminal)
	# Hiring Desk
	hire_desk = StaticBody3D.new()
	hire_desk.name = "HireDesk"
	hire_desk.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.0, 0.8)
	cs.shape = box
	hire_desk.add_child(cs)
	hire_desk.position = Vector3(0, 0.5, -5.5)
	var it := Interactable.new()
	it.name = "Interact"
	it.prompt_text = "Personal einstellen"
	it.action = &"hire"
	it.handler = self
	hire_desk.add_child(it)
	add_child(hire_desk)
	# Build-Mode andocken
	build_mode = BuildMode.new()
	build_mode.name = "BuildMode"
	add_child(build_mode)
	build_mode.bind(self)

func _desk_for(terminal: StaticBody3D) -> void:
	var style := get_node_or_null(^"/root/Style") as StyleService
	var desk := Node3D.new()
	desk.position = terminal.position - Vector3(0, 1.05, 0)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 0.9, 0.8)
	mi.mesh = bm
	if style != null:
		mi.material_override = style.get_flat_material(&"hq_desk", Color(0.4, 0.3, 0.22), 0.85)
	desk.add_child(mi)
	add_child(desk)

func can_use(_player: Node) -> bool:
	return true

func do_use(player: Node, action: StringName) -> void:
	match action:
		&"hire":
			Sfx.ui_confirm()
			UI.open_hire()

# ------------------------------------------------------------------ Save --

func save_to_dict() -> Dictionary:
	var base: Dictionary = super()
	base["hq"] = build_mode.save_to_dict() if build_mode != null else {}
	return base

func apply_save_state(d: Dictionary) -> void:
	super(d)
	if build_mode != null and d.has("hq"):
		build_mode.apply_save_data(d["hq"])
