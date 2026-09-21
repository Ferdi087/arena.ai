extends RefCounted
class_name CityLayout
## Das Straßennetz der Stadt als Graph – DIE gemeinsame Quelle für:
##  * Minimapa/Kartenansicht + Route (#54)
##  * Verkehrsrouten (TrafficManager)
##  * Ziel-Punkte für Wegweiser-UI
## Grid-Modell: Straßen an Rasterlinien, Kreuzungen = Knoten. A* hier.

const GRID := 8                 # 8x8 Kreuzungen
const SPACING := 26.0           # Meter zwischen Straßen
const ROAD_WIDTH := 8.0
const BLOCK_HALF := (SPACING - ROAD_WIDTH) * 0.5

enum District { RESIDENTIAL, DOWNTOWN, INDUSTRY, SUBURBS, VILLA, HARBOR, PARK }

static func node_pos(i: int, j: int) -> Vector3:
	return Vector3((float(i) - float(GRID) * 0.5) * SPACING, 0.0, (float(j) - float(GRID) * 0.5) * SPACING)

static func district_at(cell: Vector2i) -> int:
	var cx := float(cell.x) - float(GRID) * 0.5
	var cy := float(cell.y) - float(GRID) * 0.5
	var dist := absf(cx) + absf(cy)
	if dist < 2.0:
		return District.DOWNTOWN
	if cx < -2.0 and cy > 2.0:
		return District.INDUSTRY
	if cx > 2.0 and cy > 2.0:
		return District.HARBOR
	if cx > 2.0 and cy < -2.5:
		return District.VILLA
	if absf(cx) < 1.5 and cy < -3.0:
		return District.PARK
	return District.RESIDENTIAL

## A* über das Raster (4-Nachbarn). Gibt Welt-Positionen der Wegpunkte zurück.
static func route(from_pos: Vector3, to_pos: Vector3) -> PackedVector3Array:
	var start := nearest_node(from_pos)
	var goal := nearest_node(to_pos)
	var open: Array[Dictionary] = []
	var g := {}
	var came := {}
	var sk := key(start)
	var gk := key(goal)
	g[sk] = 0.0
	open.append({"k": sk, "i": start.x, "j": start.y, "f": heuristic(start, goal)})
	var closed := {}
	var iter := 0
	while not open.is_empty() and iter < 4096:
		iter += 1
		# billig: Min-Suche (Raster ist klein – kein Heap nötig)
		var best_idx := 0
		for i in open.size():
			if float(open[i]["f"]) < float(open[best_idx]["f"]):
				best_idx = i
		var cur: Dictionary = open.pop_at(best_idx)
		var ck := cur["k"]
		if closed.has(ck):
			continue
		closed[ck] = true
		if ck == gk:
			return reconstruct(came, goal)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := Vector2i(int(cur["i"]), int(cur["j"])) + d
			if n.x < 0 or n.y < 0 or n.x >= GRID or n.y >= GRID:
				continue
			var nk := key(n)
			if closed.has(nk):
				continue
			var tentative: float = float(g[ck]) + SPACING
			if not g.has(nk) or tentative < float(g[nk]):
				g[nk] = tentative
				came[nk] = ck
				open.append({"k": nk, "i": n.x, "j": n.y, "f": tentative + heuristic(n, goal)})
	return PackedVector3Array([to_pos])

static func reconstruct(came: Dictionary, goal: Vector2i) -> PackedVector3Array:
	var path: PackedVector3Array = []
	var k := key(goal)
	while came.has(k):
		var parts := String(k).split(",")
		path.append(node_pos(int(parts[0]), int(parts[1])))
		k = String(came[k])
	var parts0 := String(k).split(",")
	path.append(node_pos(int(parts0[0]), int(parts0[1])))
	path.reverse()
	return path

static func heuristic(a: Vector2i, b: Vector2i) -> float:
	return float(absi(a.x - b.x) + absi(a.y - b.y)) * SPACING

static func nearest_node(p: Vector3) -> Vector2i:
	var i := int(clampf(roundf(p.x / SPACING + GRID * 0.5), 0, float(GRID - 1)))
	var j := int(clampf(roundf(p.z / SPACING + GRID * 0.5), 0, float(GRID - 1)))
	return Vector2i(i, j)

static func key(n: Vector2i) -> String:
	return "%d,%d" % [n.x, n.y]

static func distance_estimate(from_pos: Vector3, to_pos: Vector3) -> float:
	var r := route(from_pos, to_pos)
	var total := 0.0
	var prev := from_pos
	for p in r:
		total += prev.distance_to(p)
		prev = p
	return total
