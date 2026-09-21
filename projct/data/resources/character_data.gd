extends Resource
class_name CharacterData
## Aussehen + Proportionen + Paint-Referenzen des Spielers (#7/#6).
## Werte sind 0..1-normalisiert; CharacterVisual mappt sie auf prozedurale
## Skalierung ODER Blend-Shape-Drift (sobald echtes Mesh existiert, #7:
## `Skeleton3D.set_blend_shape_value`-Pfad ist in CharacterVisual vorbereitet).

@export var display_name: String = "Hansi Hubwagen"

@export_group("Body Morphs (0..1)")
@export_range(0.0, 1.0, 0.001) var height: float = 0.5
@export_range(0.0, 1.0, 0.001) var width: float = 0.5
@export_range(0.0, 1.0, 0.001) var belly: float = 0.4
@export_range(0.0, 1.0, 0.001) var shoulder_width: float = 0.5
@export_range(0.0, 1.0, 0.001) var head_size: float = 0.45
@export_range(0.0, 1.0, 0.001) var head_width: float = 0.5
@export_range(0.0, 1.0, 0.001) var arm_length: float = 0.5
@export_range(0.0, 1.0, 0.001) var leg_length: float = 0.5
@export_range(0.0, 1.0, 0.001) var hand_size: float = 0.5
@export_range(0.0, 1.0, 0.001) var foot_size: float = 0.5
@export_range(0.0, 1.0, 0.001) var neck_length: float = 0.4
@export_range(0.0, 1.0, 0.001) var weight_class: float = 0.5

@export_group("Colors")
@export var skin_color: Color = Color(0.96, 0.78, 0.62)
@export var shirt_color: Color = Color(0.9, 0.3, 0.25)
@export var pants_color: Color = Color(0.2, 0.28, 0.45)

@export_group("Cosmetics (ids)")
@export var equipped: Array[StringName] = [] # slot-ids: hat, glasses, vest, backpack…

@export_group("Paint")
## 4 Quadrat-Paint-Ebenen (Front/Back/Left/Right) in EINER 512²-Textur.
@export var paint_path: String = "" # user://saves/paint/char_<slot>.png
@export var paint_base_color: Color = Color(1, 1, 1, 1) # Multiply-Tint unter der Paint-Layer

func clone_data() -> CharacterData:
	var c: CharacterData = duplicate() as CharacterData
	c.equipped = equipped.duplicate()
	return c
