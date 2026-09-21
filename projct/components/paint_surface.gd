extends Node
class_name PaintSurface
## Component: macht den Material-Körper eines 3D-Nodes bespraybar/bemalbar.
## Hält ein 512²-Quadranten-Image + ImageTexture und versorgt das Paint-Shader-
## Material. Persistenz: to_base64()/from_base64(). Multiplayer: Strokes als
## kompakte Dicts replizieren (siehe InteractionManager).
##
## Owner-Erwartung: Node3D mit get_view_rect()-Hintersinn – wir nutzen den
## übergebenen paint_size (AABB) des Owners.

signal texture_updated

var image: Image
var texture: ImageTexture
var material: ShaderMaterial
var paint_size: Vector3 = Vector3.ONE
var paint_center_offset: Vector3 = Vector3.ZERO
var _dirty: bool = false
var _stroke_counter: int = 0

func _ready() -> void:
	_ensure_texture()
	add_to_group("paint_surfaces")

func _ensure_texture() -> void:
	if image == null:
		image = Image.create(PaintProjector.TEX_SIZE, PaintProjector.TEX_SIZE, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
	if texture == null:
		texture = ImageTexture.create_from_image(image)
		_apply_material_texture()

## Owner (Node3D mit Mesh) ruft das nach Materialaufbau auf.
func bind_material(mat: ShaderMaterial, size_hint: Vector3, center: Vector3 = Vector3.ZERO) -> void:
	material = mat
	paint_size = maxf0(size_hint)
	paint_center_offset = center
	_ensure_texture()
	_apply_material_texture()

static func maxf0(v: Vector3) -> Vector3:
	return Vector3(maxf(v.x, 0.2), maxf(v.y, 0.2), maxf(v.z, 0.2))

func _apply_material_texture() -> void:
	if material != null and texture != null:
		material.set_shader_parameter("paint_texture", texture)

func stroke_at_world(hit_local: Vector3, normal_local: Vector3, params: Dictionary) -> Dictionary:
	## params: color:Color, radius:float, tool:PaintProjector.Tool, hardness:float, pattern
	## Rückgabe: kompakter Stroke-Record fürs Netzwerk/Save.
	var res := PaintProjector.project_hit(hit_local, normal_local, paint_size)
	if res.is_empty():
		return {}
	var quad: int = res[0]
	var uv: Vector2 = res[1]
	var color: Color = params.get("color", Color(1, 0.2, 0.2))
	var radius: float = float(params.get("radius", 0.05))
	var tool: int = int(params.get("tool", PaintProjector.Tool.BRUSH))
	var hardness: float = float(params.get("hardness", 0.5))
	var pattern: StringName = params.get("pattern", &"solid")
	_stroke_counter += 1
	PaintProjector.stamp(image, quad, uv, radius, color, tool as PaintProjector.Tool, hardness, _stroke_counter, pattern)
	_dirty = true
	if material != null:
		material.set_shader_parameter("paint_center", paint_center_offset)
		material.set_shader_parameter("paint_size", paint_size)
	var record := {
		"q": quad, "u": snappedf(uv.x, 0.002), "v": snappedf(uv.y, 0.002),
		"r": snappedf(radius, 0.002), "c": color.to_html(), "t": tool, "h": snappedf(hardness, 0.01),
		"p": String(pattern), "s": _stroke_counter,
	}
	return record

## Netzwerk-Replay eines Strokes.
func replay_stroke(record: Dictionary) -> void:
	var quad: int = int(record.get("q", 0))
	var uv := Vector2(float(record.get("u", 0.5)), float(record.get("v", 0.5)))
	var color := Color(String(record.get("c", "ff3333ff")))
	var radius := float(record.get("r", 0.05))
	var tool := int(record.get("t", PaintProjector.Tool.BRUSH))
	var hardness := float(record.get("h", 0.5))
	var pattern := StringName(String(record.get("p", "solid")))
	var seedv := int(record.get("s", 0))
	PaintProjector.stamp(image, quad, uv, radius, color, tool as PaintProjector.Tool, hardness, seedv, pattern)
	_dirty = true
	_stroke_counter = maxi(_stroke_counter, seedv)
	EventBus.paint_stroke_finished.emit(&"surface", quad)

func commit_frame() -> void:
	if not _dirty or texture == null or image == null:
		return
	_dirty = false
	texture.update(image)
	texture_updated.emit()

## Kompakte Persistenz: nur komprimiertes PNG als Base64 (leer wenn unbenutzt).
func to_base64() -> String:
	if image == null:
		return ""
	commit_frame()
	# Early-out: komplett leeres Image -> kein Byte verschwenden
	if _is_empty():
		return ""
	var img := image.duplicate()
	# Transparenz-Erhalt: save PNG unterstützt RGBA.
	var err := img.save_png("user://saves/_tmp_paint.png")
	if err != OK:
		push_warning("PaintSurface: PNG-Export fehlgeschlagen (%s)" % error_string(err))
		return ""
	var f := FileAccess.open("user://saves/_tmp_paint.png", FileAccess.READ)
	if f == null:
		return ""
	var bytes := f.get_buffer(f.get_length())
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/_tmp_paint.png"))
	return Marshalls.buffer_to_base64(bytes)

func from_base64(b64: String) -> void:
	if b64.is_empty():
		return
	var bytes := Marshalls.base64_to_raw(b64)
	if bytes.is_empty():
		push_warning("PaintSurface: Basis64 defekt – Paint ignoriert.")
		return
	var img := Image.new()
	var err := img.load_png_from_buffer(bytes)
	if err != OK or img.get_width() != PaintProjector.TEX_SIZE:
		push_warning("PaintSurface: PNG-Decodieren fehlgeschlagen – Paint ignoriert.")
		return
	_ensure_texture()
	image = img
	commit_frame()

func _is_empty() -> bool:
	if image == null:
		return true
	for y in range(0, PaintProjector.TEX_SIZE, 4):
		for x in range(0, PaintProjector.TEX_SIZE, 4):
			if image.get_pixel(x, y).a > 0.01:
				return false
	return true
