extends Control
class_name MapWidget
## Minimapa + Vollkarte in EINEM Widget (Modus: minimap/full). Zeichnet pro
## Frame direkt via _draw – für ~80 Linien billiger als Nodes. Daten aus
## CityLayout (Straßen) + POIs + Route des aktiven Auftrags (#54).

@export var full: bool = false
var follow: Node3D = null

const SCALE_MINI := 1.18
const SCALE_FULL := 5.4

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if follow == null:
		await get_tree().process_frame
		follow = get_tree().get_first_node_in_group("players")
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center := Vector3.ZERO
	if follow != null and is_instance_valid(follow):
		center = follow.global_position
	var sc := SCALE_FULL if full else SCALE_MINI
	var half := size * 0.5
	# Hintergrund
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.09, 0.86 if not full else 0.96))
	# Straßenraster
	for i in CityLayout.GRID:
		for j in CityLayout.GRID:
			var p := CityLayout.node_pos(i, j)
			var sp := _world_to_screen(p, center, sc, half)
			var r := maxf(CityLayout.ROAD_WIDTH * sc * 0.5, 1.0)
			draw_circle(sp, r, Color(0.22, 0.24, 0.28))
	# Gebäude als Rechtecke grob
	for node in get_tree().get_nodes_in_group("world"):
		var city := node.get_node_or_null("City")
		if city != null:
			for b in city.get_children():
				if b is StaticBody3D:
					var sp := _world_to_screen(b.global_position, center, sc, half)
					var sz := Vector2(9.0 * sc, 9.0 * sc)
					draw_rect(Rect2(sp - sz * 0.5, sz), Color(0.34, 0.3, 0.26, 0.9))
	# Route wenn Mission aktiv
	if Missions.has_active_mission() and follow != null:
		var target := _mission_target_world(center)
		if target != Vector3.INF:
			var route := CityLayout.route(follow.global_position, target)
			var pts := PackedVector2Array()
			for rp in route:
				pts.append(_world_to_screen(rp, center, sc, half))
			if pts.size() >= 2:
				var poly := PackedVector2Array()
				poly.resize(pts.size())
				for i in pts.size():
					poly[i] = _world_to_screen(route[i], center, sc, half)
				draw_polyline(poly, Color(0.95, 0.62, 0.12, 0.9), maxf(sc * 1.6, 2.0))
				var tp := _world_to_screen(target, center, sc, half)
				draw_circle(tp, 7.0, Color(0.95, 0.3, 0.25))
	# Spieler
	draw_circle(half, 5.0, Color(0.3, 0.9, 0.5))
	if full:
		var lbl := "KARTE (M/Esc schließen)"
		draw_string(ThemeDB.fallback_font, Vector2(14, 26), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.9, 0.95))

func _world_to_screen(p: Vector3, center: Vector3, sc: float, half: Vector2) -> Vector2:
	var rel := p - center
	return Vector2(half.x + rel.x * sc, half.y + rel.z * sc)

func _mission_target_world(from: Vector3) -> Vector3:
	# Ziel = Truck wenn beladen, sonst Quellzone, sonst HQ-Nähe
	var w := get_tree().get_first_node_in_group("world") as WorldRoot
	if w == null:
		return Vector3.INF
	if w.mission_runtime != null:
		var rt := w.mission_runtime
		var v := w.find_vehicle()
		if v != null and v.cargo_items.size() > 0 and rt.mission_zone_dest != null:
			return rt.mission_zone_dest.global_position
		if rt.mission_zone_source != null:
			return rt.mission_zone_source.global_position
	return Vector3.INF
