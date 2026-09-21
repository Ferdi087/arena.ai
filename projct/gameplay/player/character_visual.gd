extends Node3D
class_name CharacterVisual
## Prozedurale Cartoon-Humanoid-Visual mit Morph-Skalierung + Paint-Layer.
##
## Architekturentscheidung (#7/#101): Die Morph-Werte (0..1) werden hier auf
## primitive Mesh-Transforms gemappt. Sobald ein echtes GLB mit BlendShapes da
## ist, übernimmt _apply_blendshapes() den identischen Wertebereich – kein
## anderes System muss sich ändern, CharacterData bleibt die Schnittstelle.

var data: CharacterData = null
var _parts: Dictionary[String, MeshInstance3D] = {}
var _materials: Array[ShaderMaterial] = []
var _paint_surface: PaintSurface = null
var _squash_t: float = 1.0
var _squash_speed: float = 0.0
var _blend_shape_ids: Dictionary[String, int] = {}

@export var base_height: float = 1.62

func _ready() -> void:
	if data == null:
		data = Characters.current_character
	build_body()
	Characters.character_applied.connect(_on_character_applied)

func _on_character_applied(c: CharacterData) -> void:
	data = c
	if not _parts.is_empty():
		apply_morphs()

func build_body() -> void:
	# Torso/Hals/Kopf/Arme/Beine/Hände/Füße – alles eigene MeshInstances, damit
	# Morphs unabhängig skalieren (kein Monolith-Mesh für die Slice-Phase).
	_mat_part("Torso", Color.WHITE)
	_mat_part("Head", Color.WHITE)
	_mat_part("Neck", Color.WHITE)
	_mat_part("ArmL", Color.WHITE)
	_mat_part("ArmR", Color.WHITE)
	_mat_part("HandL", Color.WHITE)
	_mat_part("HandR", Color.WHITE)
	_mat_part("LegL", Color.WHITE)
	_mat_part("LegR", Color.WHITE)
	_mat_part("FootL", Color.WHITE)
	_mat_part("FootR", Color.WHITE)
	apply_morphs()

func _mat_part(name_s: String, _tint: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name_s
	var style := get_node_or_null(^"/root/Style") as StyleService
	var mat: ShaderMaterial = style.make_paint_material(Color.WHITE, Vector3.ONE) if style != null else ShaderMaterial.new()
	mi.material_override = mat
	_materials.append(mat)
	add_child(mi)
	_parts[name_s] = mi

func apply_morphs() -> void:
	if data == null:
		return
	var h := lerpf(0.86, 1.18, data.height)              # Gesamtgröße
	var girth := lerpf(0.8, 1.45, clampf((data.width + data.weight_class) * 0.5, 0.0, 1.0))
	var belly := data.belly
	var shoulder := lerpf(0.8, 1.3, data.shoulder_width)
	var head := lerpf(0.8, 1.35, data.head_size)
	var headw := lerpf(0.85, 1.25, data.head_width)
	var armL := lerpf(0.8, 1.25, data.arm_length)
	var legL := lerpf(0.8, 1.3, data.leg_length)
	var handS := lerpf(0.75, 1.4, data.hand_size)
	var footS := lerpf(0.75, 1.5, data.foot_size)
	var neck := lerpf(0.5, 1.6, data.neck_length)

	var leg_h := 0.62 * legL * h
	var torso_h := (base_height - leg_h) * 0.62
	var torso_w := 0.42 * girth * shoulder
	var torso_d := 0.26 * girth * (1.0 + belly * 0.55)
	var head_y := leg_h + torso_h + 0.085 * neck

	_size_part("LegL", Vector3(0.15 * girth, leg_h, 0.15 * girth), Vector3(-torso_w * 0.38 + 0.02, leg_h * 0.5, 0))
	_size_part("LegR", Vector3(0.15 * girth, leg_h, 0.15 * girth), Vector3(torso_w * 0.38 - 0.02, leg_h * 0.5, 0))
	_size_part("FootL", Vector3(0.19 * footS * girth, 0.09, 0.30 * footS), Vector3(-torso_w * 0.38 + 0.02, 0.045, 0.07 * footS))
	_size_part("FootR", Vector3(0.19 * footS * girth, 0.09, 0.30 * footS), Vector3(torso_w * 0.38 - 0.02, 0.045, 0.07 * footS))
	_size_part("Torso", Vector3(torso_w, torso_h, torso_d), Vector3(0, leg_h + torso_h * 0.5, 0))
	_size_part("Neck", Vector3(0.1, 0.09 * neck + 0.03, 0.1), Vector3(0, head_y - 0.045 * neck, 0))
	_size_part("Head", Vector3(0.30 * headw * head, 0.32 * head, 0.30 * head), Vector3(0, head_y + 0.18 * head, 0))
	var arm_y := leg_h + torso_h * 0.82
	_size_part("ArmL", Vector3(0.115 * girth, 0.5 * armL * h * 0.62, 0.115 * girth), Vector3(-(torso_w * 0.5 + 0.075), arm_y - 0.5 * armL * 0.31 * h, 0))
	_size_part("ArmR", Vector3(0.115 * girth, 0.5 * armL * h * 0.62, 0.115 * girth), Vector3(torso_w * 0.5 + 0.075, arm_y - 0.5 * armL * 0.31 * h, 0))
	_size_part("HandL", Vector3(0.13 * handS, 0.13 * handS, 0.13 * handS), Vector3(-(torso_w * 0.5 + 0.075), arm_y - 0.5 * armL * h * 0.32, 0))
	_size_part("HandR", Vector3(0.13 * handS, 0.13 * handS, 0.13 * handS), Vector3(torso_w * 0.5 + 0.075, arm_y - 0.5 * armL * h * 0.32, 0))

	# Farben: Haut an Kopf/Hande, Shirt an Torso/Arme, Hose an Beine
	_set_part_color("Head", data.skin_color)
	_set_part_color("HandL", data.skin_color)
	_set_part_color("HandR", data.skin_color)
	_set_part_color("Neck", data.skin_color)
	_set_part_color("Torso", data.shirt_color)
	_set_part_color("ArmL", data.shirt_color)
	_set_part_color("ArmR", data.shirt_color)
	_set_part_color("LegL", data.pants_color)
	_set_part_color("LegR", data.pants_color)
	_set_part_color("FootL", Color(0.15, 0.12, 0.1))
	_set_part_color("FootR", Color(0.15, 0.12, 0.1))
	# Paint-Size: gesamter Body-Bounds für Box-Projektion (Shader-Uniforms).
	var full_h := head_y + 0.36 * head
	if _paint_surface == null:
		_paint_surface = PaintSurface.new()
		_paint_surface.name = "Paint"
		add_child(_paint_surface)
	for m in _materials:
		if m != null:
			m.set_shader_parameter("paint_size", Vector3(torso_w * 1.9, full_h, torso_d * 2.2))
			m.set_shader_parameter("paint_center", Vector3(0, full_h * 0.5, 0))
	_paint_surface.bind_material(_materials[0], Vector3(torso_w * 1.9, full_h, torso_d * 2.2), Vector3(0, full_h * 0.5, 0))
	# Alle Material-Instanzen teilen sich dieselbe Paint-Textur:
	for m in _materials:
		if m != null and _paint_surface.texture != null:
			m.set_shader_parameter("paint_texture", _paint_surface.texture)

func get_paint_surface() -> PaintSurface:
	return _paint_surface

func get_part(name_s: String) -> MeshInstance3D:
	return _parts.get(name_s)

## BlendShape-Pfad für später (Doku #7): identische API, echte Drift-Werte.
func _apply_blendshapes() -> void:
	var sk := get_node_or_null("Skeleton3D") as Skeleton3D
	if sk == null:
		return
	for morph_name in _blend_shape_ids:
		var idx: int = _blend_shape_ids[morph_name]
		var v: float = float(data.get(morph_name)) if data != null else 0.0
		sk.set_blend_shape_value(idx, v)

func _size_part(name_s: String, size: Vector3, pos: Vector3) -> void:
	var mi := _parts.get(name_s)
	if mi == null:
		return
	var mesh := mi.mesh as BoxMesh
	if mesh == null:
		mesh = BoxMesh.new()
		mi.mesh = mesh
	mesh.size = max3(size)
	mi.position = pos

static func max3(v: Vector3) -> Vector3:
	return Vector3(maxf(v.x, 0.02), maxf(v.y, 0.02), maxf(v.z, 0.02))

func _set_part_color(name_s: String, c: Color) -> void:
	var mi := _parts.get(name_s)
	if mi == null:
		return
	var m := mi.material_override as ShaderMaterial
	if m != null:
		m.set_shader_parameter("base_color", Vector4(c.r, c.g, c.b, 1.0))
		m.set_shader_parameter("roughness", 0.78)

func play_jump_squash() -> void:
	_squash_t = 1.0
	_squash_speed = 6.5

func _process(delta: float) -> void:
	if _squash_speed <= 0.0:
		return
	_squash_t = clampf(_squash_t - delta * _squash_speed, 0.0, 1.0)
	_squash_speed = maxf(0.0, _squash_speed - delta * 14.0)
	var s := 1.0 + sin(_squash_t * PI) * 0.22
	scale = Vector3(1.0 / sqrt(s), s, 1.0 / sqrt(s))

func begin_ragdoll_visuals() -> void:
	for p in _parts:
		var mi := _parts[p]
		if mi != null:
			mi.visible = false

func end_ragdoll_visuals() -> void:
	for p in _parts:
		var mi := _parts[p]
		if mi != null:
			mi.visible = true
