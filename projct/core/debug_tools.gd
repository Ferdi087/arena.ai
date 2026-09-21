extends Node
## Debug Tools (Autoload "Dev") – F3-Overlay + Cheats, in Release abgeschaltet.
##
## Release-Gate: Engine.is_editor_hint() false UND OS.has_feature("template") true
## -> alles hier wird zu no-ops (#73). Kein Release-Overhead außer zwei bool-Checks.
##
## Anzeige: FPS/MS, Physik-Ticks, aktives Grab-Ziel, Damage, Netzwerk, Mission.
## Cheats: Geld, Zeit, Wetter, Objekt-Spawn, Collision-Overlay.

var overlay: CanvasLayer
var label: RichTextLabel
var enabled: bool = false
var _update_accum: float = 0.0

static func _dev_enabled() -> bool:
	return Engine.is_editor_hint() or not OS.has_feature("template")

func _ready() -> void:
	if not _dev_enabled():
		set_process(false)
		set_physics_process(false)
		return
	overlay = CanvasLayer.new()
	overlay.layer = 90
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.position = Vector2(12, 12)
	label.size = Vector2(420, 260)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.85))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.04, 0.72)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	label.add_theme_stylebox_override("normal", style)
	overlay.add_child(label)
	enabled = false
	label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _dev_enabled():
		return
	if event.is_action_pressed("debug_toggle_hud"):
		enabled = not enabled
		label.visible = enabled
	elif event.is_action_pressed("debug_add_money"):
		Company.add_money(10000.0, "debug")
	elif event.is_action_pressed("debug_spawn_box"):
		_spawn_debug_crate()

func _process(delta: float) -> void:
	if not enabled:
		return
	_update_accum += delta
	if _update_accum < 0.25:
		return
	_update_accum = 0.0
	label.text = _build_text()

func _build_text() -> String:
	var grab_info := "kein Grab"
	var world := get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("debug_grab_info"):
		grab_info = world.call("debug_grab_info")
	var mission_info := "keine Mission"
	if Missions.has_active_mission():
		var m := Missions.active_mission
		var done := 0
		for o in m.objectives:
			if o.completed:
				done += 1
		mission_info = "%s (%d/%d Obj.)" % [m.display_name, done, m.objectives.size()]
	var net := "OFFLINE (Singleplayer)"
	match Net.mode:
		Net.Mode.HOST: net = "HOST peers=%d" % multiplayer.get_peers().size()
		Net.Mode.CLIENT: net = "CLIENT authoritative=%s" % str(multiplayer.is_server())
		Net.Mode.SPLIT_LOCAL: net = "LOCAL COOP players=%d" % Game.local_coop_players
	return "[b]HAUL-O-VERSE DEBUG[/b]\nFPS %d | frame %.1f ms | physics %.2f ms\nNodes: %d | Objekte: %d\n%s\nGrab: %s\nMission: %s\nGeld: %.0f | Rep: %.0f | Level %d" % [
		int(Performance.get_monitor(Performance.TIME_FPS)),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		grab_info, mission_info,
		Company.money, Company.reputation, Company.company_level,
	]

# ------------------------------------------------------------------- Cheats --

func debug_enabled_in_hud() -> bool:
	return enabled and _dev_enabled()

func set_money(amount: float) -> void:
	if _dev_enabled():
		Company.money = amount
		EventBus.money_changed.emit(amount, 0.0)

func complete_active_mission() -> void:
	if _dev_enabled() and Missions.has_active_mission():
		Missions.debug_force_complete()

func _spawn_debug_crate() -> void:
	if not _dev_enabled():
		return
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("spawn_furniture"):
		push_warning("Dev: keine Welt-Szene mit spawn_furniture() gefunden")
		return
	var data := Content.get_furniture(&"cardboard_small")
	if data == null:
		push_warning("Dev: FurnitureData cardboard_small fehlt")
		return
	world.call("spawn_furniture", data, Vector3(0, 3, 0))
