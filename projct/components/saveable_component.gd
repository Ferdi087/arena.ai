extends Node
class_name SaveableComponent
## Markiert einen Welt-Node als persistent (Platzierung/Position/Sonderdaten).
## Der Owner (Node3D) muss get_save_transform()/apply_save_transform() haben;
## SaveableComponent sammelt sich Szenezitig über die Gruppe "saveable".

@export var save_key: String = ""
@export var extra_props: PackedStringArray = PackedStringArray()

func capture(owner: Node3D) -> Dictionary:
	var d := {
		"key": save_key if save_key != "" else String(owner.name),
		"x": owner.global_position.x, "y": owner.global_position.y, "z": owner.global_position.z,
		"rx": owner.rotation.x, "ry": owner.rotation.y, "rz": owner.rotation.z,
	}
	if owner.has_method("get_save_data"):
		d["data"] = owner.call("get_save_data")
	return d
