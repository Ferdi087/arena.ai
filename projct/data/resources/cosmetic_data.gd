extends Resource
class_name CosmeticData
## Accessoires/Kleidung mit Freischalt- und Physik-Hooks (#11/#12).

enum Slot { HAT, FACE, NECK, BACK, TORSO, LEGS, HANDS }

@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: Slot = Slot.HAT
@export var price: float = 0.0
@export var unlock_company_level: int = 0
@export var unlock_reputation: float = 0.0
@export var unlock_flag: StringName = &"" # Achievement/Secret-Flag aus Company.unlocked_flags
@export_group("Visual / Physics")
@export var attach_node: StringName = &"Head" # an CharacterVisual
@export var local_offset: Vector3 = Vector3.ZERO
@export var procedural_style: StringName = &"box" # wie das Accessoire prozedural gebaut wird
@export var color: Color = Color(0.8, 0.2, 0.2)
@export var is_physical: bool = false # Schal: Ropes/Spring-Bones
@export var physical_segments: int = 0 # z. B. Schal 6 Segmente
@export var tags: PackedStringArray = PackedStringArray() # ["funny","seasonal","hazard"]

func is_unlocked_for(company: Node) -> bool:
	if price > 0.0 and not company.has_purchased(id):
		return false
	if company.company_level < unlock_company_level:
		return false
	if company.reputation < unlock_reputation:
		return false
	if unlock_flag != &"" and not company.has_unlock(unlock_flag):
		return false
	return true
