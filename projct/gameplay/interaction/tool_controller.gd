extends Node
class_name ToolController
## Werkzeug-Slots (Hand, Spraydosen, Besen, Hammer, Laubbläser) – #35/#40/#93.
## Kind-Knoten des InteractionManagers. Werkzeuge sind datengetrieben über
## ToolDef (hier statisch registriert, später res://data/definitions/tools/*.tres).
## Kein Inventar-Müll: große Möbel bleiben Physikobjekte; nur Werkzeuge haben Slots.

enum ToolKind { HAND, SPRAY, SPRAY_FINE, SPRAY_NEON, BROOM, HAMMER, BLOWER }

class ToolDef:
	var kind: ToolKind = ToolKind.HAND
	var display_name: String = ""
	var paint: bool = false
	var radius_scale: float = 1.0
	var hardness: float = 0.5
	var can_damage: bool = false
	var damage_points: float = 6.0
	var push_force: float = 0.0
	var push_radius: float = 2.0

	static func make(k: ToolKind, name_s: String, p_paint: bool, r: float, h: float, dmg: float, force: float) -> ToolDef:
		var t := ToolDef.new()
		t.kind = k; t.display_name = name_s; t.paint = p_paint
		t.radius_scale = r; t.hardness = h
		t.can_damage = dmg > 0.0; t.damage_points = dmg
		t.push_force = force
		return t

var registry: Dictionary = {}
var slots: Array[ToolDef] = []          # aktive Hotbar (5)
var active_index: int = 0
var paint_color: Color = Color(0.9, 0.15, 0.15)
var paint_size_mult: float = 1.0
var pattern: StringName = &"solid"      # solid|stripes|dots|glow

var _manager: InteractionManager = null
var _spray_active: bool = false

signal tool_changed(tool: ToolDef)
signal palette_changed(color: Color, pattern: StringName)

func _ready() -> void:
	_manager = get_parent() as InteractionManager
	_register_defaults()
	set_slots([ToolKind.HAND, ToolKind.SPRAY, ToolKind.BROOM, ToolKind.HAMMER, ToolKind.BLOWER])

func _register_defaults() -> void:
	registry[ToolKind.HAND] = ToolDef.make(ToolKind.HAND, "Hand", false, 1.0, 0.5, 0.0, 0.0)
	registry[ToolKind.SPRAY] = ToolDef.make(ToolKind.SPRAY, "Spraydose", true, 1.0, 0.35, 0.0, 0.0)
	registry[ToolKind.SPRAY_FINE] = ToolDef.make(ToolKind.SPRAY_FINE, "Feine Spraydose", true, 0.45, 0.8, 0.0, 0.0)
	registry[ToolKind.SPRAY_NEON] = ToolDef.make(ToolKind.SPRAY_NEON, "Neon-Spray", true, 1.1, 0.3, 0.0, 0.0)
	registry[ToolKind.BROOM] = ToolDef.make(ToolKind.BROOM, "Besen", false, 1.0, 0.5, 0.0, 26.0)
	registry[ToolKind.HAMMER] = ToolDef.make(ToolKind.HAMMER, "Hammer", false, 1.0, 0.5, 9.0, 0.0)
	registry[ToolKind.BLOWER] = ToolDef.make(ToolKind.BLOWER, "Laubbläser", false, 1.0, 0.5, 0.0, 60.0)

func set_slots(kinds: Array) -> void:
	slots.clear()
	for k in kinds:
		if registry.has(k):
			slots.append(registry[k])
	if slots.is_empty():
		slots.append(registry[ToolKind.HAND])
	active_index = clampi(active_index, 0, slots.size() - 1)

func active_tool() -> ToolDef:
	if slots.is_empty():
		return registry[ToolKind.HAND]
	return slots[clampi(active_index, 0, slots.size() - 1)]

func _unhandled_input(event: InputEvent) -> void:
	# Hotbar
	for i in 5:
		if event.is_action_pressed("tool_select_%d" % (i + 1)):
			select_index(i)
	if event.is_action_pressed("tool_next"):
		select_index(active_index + 1)
	if event.is_action_pressed("tool_previous"):
		select_index(active_index - 1)

func select_index(i: int) -> void:
	if slots.is_empty():
		return
	active_index = posmod(i, slots.size())
	tool_changed.emit(active_tool())

func tick(manager: InteractionManager) -> void:
	var tool := active_tool()
	if tool == null:
		return
	var pressed := Input.is_action_pressed("tool_use")
	# LINKSKLICK-KONFLIKT: grab(RMB) malen vs. greifen – Paint NUR wenn Werkzeug
	# aktiv ein Paint-Tool ist; die Hand nutzt tool_use als "Stupsen".
	if tool.paint and pressed:
		if not _spray_active:
			_spray_active = true
		var params := {
			"color": paint_color,
			"radius": manager.paint_radius_base * tool.radius_scale * paint_size_mult,
			"tool": PaintProjector.Tool.BRUSH if tool.kind == ToolKind.SPRAY_FINE else PaintProjector.Tool.SPRAY,
			"hardness": tool.hardness,
			"pattern": pattern if tool.kind != ToolKind.SPRAY_NEON else &"glow",
		}
		manager.begin_paint_stroke(params)
	elif tool.kind == ToolKind.HAMMER and Input.is_action_just_pressed("tool_use"):
		_swing_hammer(manager)
	elif tool.kind in [ToolKind.BROOM, ToolKind.BLOWER] and pressed:
		_push_area(tool, manager, Input.get_action_strength("tool_use"))
	else:
		_spray_active = false

func set_paint_color(c: Color) -> void:
	paint_color = c
	palette_changed.emit(paint_color, pattern)

func set_pattern(p: StringName) -> void:
	pattern = p
	palette_changed.emit(paint_color, pattern)

func _swing_hammer(manager: InteractionManager) -> void:
	var body := manager.hovered as FurnitureBody
	if body == null:
		return
	var dmg := body.get_node_or_null("Damage") as DamageComponent
	if dmg != null:
		dmg.apply_tool_damage(active_tool().damage_points, manager.get_hit_local(body), &"tool")
	else:
		push_warning("ToolController: Ziel ohne DamageComponent – Hammer tut nichts (robust, kein Crash #102)")

func _push_area(tool: ToolDef, manager: InteractionManager, strength: float) -> void:
	# Kegel um Blickrichtung: leichte Objekte werden physikalisch bewegt (#26 Wind-Bruder).
	var origin := manager.get_player().global_position + manager.get_player().get_look_dir() * 0.6
	var dir := manager.get_player().get_look_dir()
	var radius := tool.push_radius
	for node in get_tree().get_nodes_in_group("furniture"):
		var b := node as FurnitureBody
		if b == null or b.locked_in_cargo:
			continue
		var to := b.global_position - origin
		var d := to.length()
		if d > radius:
			continue
		if d < 0.05:
			continue
		var align := to.normalized().dot(dir)
		if align < 0.6:
			continue
		var falloff := lerpf(1.0, 0.25, clampf(d / radius, 0.0, 1.0))
		var lightness := clampf(1.0 - b.mass / 80.0, 0.0, 1.0)
		b.apply_impulse(dir * tool.push_force * strength * falloff * lightness * b.mass * 0.05)

