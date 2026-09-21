extends StaticBody3D
class_name ComputerTerminal
## Der Firmen-Computer: Interactable -> öffnet Rechner-UI (Missionen, Marketing,
## Mitarbeiter, Website, Statistiken, Speichern). Kein Monolith: die Panels
## liefert UIService, wir feuern nur den Request + Sound. (#17)

@export var terminal_role: StringName = &"company" # company|shop_vehicle|shop_clothes|shop_build|garage

func _ready() -> void:
	if get_node_or_null("Interact") == null:
		var it := Interactable.new()
		it.name = "Interact"
		match String(terminal_role):
			"garage":
				it.prompt_text = "Garage-Terminal (Upgrades/Reparatur/Lack)"
			"shop_vehicle":
				it.prompt_text = "Fahrzeughändler"
			"shop_clothes":
				it.prompt_text = "Kleidung & Accessoires"
			"shop_build":
				it.prompt_text = "Material kaufen"
			_:
				it.prompt_text = "Firmen-Computer"
		it.action = &"open_terminal"
		it.handler = self
		add_child(it)
	# Monitor-Emission als Leben:
	if get_node_or_null("Screen") == null:
		var mi := MeshInstance3D.new()
		mi.name = "Screen"
		var qm := QuadMesh.new()
		qm.size = Vector2(0.62, 0.4)
		mi.mesh = qm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.07, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(0.25, 0.5, 0.85)
		mat.emission_energy_multiplier = 1.6
		mi.material_override = mat
		add_child(mi)
		mi.position = Vector3(0, 0.55, -0.1)

func can_use(_player: Node) -> bool:
	return true

func do_use(player: Node, _action: StringName) -> void:
	Sfx.ui_confirm()
	match String(terminal_role):
		"garage":
			UI.open_garage()
		"shop_vehicle":
			UI.open_shop_vehicle()
		"shop_clothes":
			UI.open_shop_clothes()
		"shop_build":
			UI.open_shop_build()
		_:
			UI.open_mission_board(player)
