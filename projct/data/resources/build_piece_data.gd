extends Resource
class_name BuildPieceData
## Baumodus-Baustein (#14/#15): Wände, Böden, Decken, Türen, Fenster, Treppen,
## Deko. Grid-basiert mit Fein-Verschiebung (Nudge) im BuildMode.

enum Kind { WALL, FLOOR, CEILING, DOOR, WINDOW, STAIR, DECOR, LIGHT, WORKBENCH }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.WALL
@export var cost: float = 100.0
@export var required_company_level: int = 0
@export var grid_footprint: Vector2i = Vector2i(1, 1) # in Zellen (0.5m Raster)
@export var height_m: float = 2.6
@export var stability: float = 1.0 # 0..1 – beeinflusst HQ-Qualität + Wackeln
@export var material: MaterialDef
@export var hq_quality_score: float = 1.0 # Contribution zu #16
@export var variants: int = 1 # visuelle Variante (Zyklus mit R)
@export var rotation_snaps: int = 4 # 4=90°, 8=45°
@export var mesh_scene: PackedScene # später; leer = prozedural
