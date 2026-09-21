extends RefCounted
class_name PaintProjector
## Statische Paint-Mathematik: 3D-Treffer <-> 2x2-Quadranten-UV.
## Muss exakt zum Shader paint_overlay.gdshader passen (Layout-Kommentar dort).
## Auch der Painter (UI) zeichnet über diese API – eine Quelle der Wahrheit (#9).

enum Q { FRONT = 0, BACK = 1, LEFT = 2, RIGHT = 3 }
const TEX_SIZE := 512
const QUAD_SIZE := 256

const QUAD_ORIGINS := [Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(0.0, 0.5), Vector2(0.5, 0.5)]

## Hit (Welt) -> [quadrant:int, uv_in_quad:Vector2] oder leer.
static func project_hit(hit_local: Vector3, hit_normal_local: Vector3, size: Vector3) -> Array:
	var n := hit_normal_local.normalized()
	var half := size * 0.5
	if abs(n.z) >= abs(n.x) and abs(n.z) > abs(n.y):
		var front := n.z > 0.0
		var u := clampf((hit_local.x / max(half.x, 0.001)) * 0.5 + 0.5, 0.0, 1.0)
		var v := clampf((hit_local.y / max(half.y, 0.001)) * 0.5 + 0.5, 0.0, 1.0)
		if not front:
			u = 1.0 - u
		return [int(Q.FRONT) if front else int(Q.BACK), Vector2(u, v)]
	if abs(n.x) > abs(n.y):
		var right := n.x > 0.0
		var u := clampf((-hit_local.z / max(half.z, 0.001)) * 0.5 + 0.5, 0.0, 1.0)
		if right:
			u = 1.0 - u
		var v := clampf((hit_local.y / max(half.y, 0.001)) * 0.5 + 0.5, 0.0, 1.0)
		return [int(Q.RIGHT) if right else int(Q.LEFT), Vector2(u, v)]
	return []

## Quadrant+UV -> Pixelrechteck im 512² Image (Image hat Top-Left-Ursprung,
## Shader v-Achse zeigt nach oben -> y-Flip wird hier gekapselt).
static func quad_pixel_pos(quad: int, uv: Vector2) -> Vector2i:
	var origin: Vector2 = QUAD_ORIGINS[quad]
	var px := Vector2(origin.x + uv.x * 0.5, 1.0 - (origin.y + uv.y * 0.5))
	return Vector2i(int(px.x * TEX_SIZE), int(px.y * TEX_SIZE))

# ------------------------------------------------------------------- Brush-Op --

enum Tool { BRUSH, SPRAY, AIRBRUSH, ERASER }

## Stempelt einen Pinselstrich direkt ins Image. Deterministisch (kein rand())
## – damit Multiplayer-Stroke-Replays identisch aussehen (Seed wird mitgegeben).
static func stamp(image: Image, quad: int, uv: Vector2, radius_uv: float, color: Color,
		tool: Tool, hardness: float, jitter_seed: int, pattern: StringName = &"solid") -> void:
	if image == null:
		return
	var center := quad_pixel_pos(quad, uv)
	var r_px := maxi(int(radius_uv * float(TEX_SIZE)), 2)
	var paint := color
	for dy in range(-r_px, r_px + 1):
		for dx in range(-r_px, r_px + 1):
			var x := center.x + dx
			var y := center.y + dy
			if x < 0 or y < 0 or x >= TEX_SIZE or y >= TEX_SIZE:
				continue
			var d := Vector2(float(dx), float(dy)) / float(r_px)
			if d.length() > 1.0:
				continue
			var falloff := clampf((1.0 - d.length()) / maxf(1.0 - hardness, 0.05), 0.0, 1.0)
			var spray_a := falloff
			if tool == Tool.SPRAY or tool == Tool.AIRBRUSH:
				# deterministischer Rausch-Scatter
				var h := hash_pattern(Vector2i(x, y), jitter_seed)
				var threshold := 0.35 if tool == Tool.SPRAY else 0.12
				if h > threshold:
					continue
				spray_a = falloff * lerpf(0.25, 0.9, h / maxf(threshold, 0.01))
			if pattern == &"stripes":
				if int(float(y) / 6.0) % 2 == 0:
					continue
			elif pattern == &"dots":
				if ((x / 8) + (y / 8)) % 2 != 0:
					continue
			elif pattern == &"glow":
				spray_a *= 1.35
			var old := image.get_pixel(x, y)
			var final_a := clampf(spray_a * paint.a, 0.0, 1.0)
			if tool == Tool.ERASER:
				var new_a := clampf(old.a - final_a, 0.0, 1.0)
				image.set_pixel(x, y, Color(old.r, old.g, old.b, new_a))
			else:
				# Alpha-Mix (Normalmodus) von Hand – deterministisch.
				var src := Color(paint.r, paint.g, paint.b, final_a)
				var blended := Color(
					lerpf(old.r, src.r, src.a), lerpf(old.g, src.g, src.a),
					lerpf(old.b, src.b, src.a), clampf(old.a + src.a * (1.0 - old.a), 0.0, 1.0))
				image.set_pixel(x, y, blended)

static func hash_pattern(p: Vector2i, seedv: int) -> float:
	# kleiner integer hash -> 0..1
	var h: int = (p.x * 73856093) ^ (p.y * 19349663) ^ (seedv * 83492791)
	h = h % 1000
	if h < 0:
		h = -h
	return float(h) / 1000.0
