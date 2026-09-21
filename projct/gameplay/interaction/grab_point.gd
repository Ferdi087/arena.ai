extends Node3D
class_name GrabPoint
## Marker-Knoten an Furniture/Vehicle: bevorzugter Griffpunkt. Der Solver nutzt
## ihn, wenn vorhanden (realistischerer Grip als Boxmitte). Optional:
## `is_primary` für den Solo-Grab, `max_players` pro Punkt.

@export var is_primary: bool = false
@export var max_players: int = 1
@export var allowed_side: StringName = &"any"  # any|left|right (Co-Op-Rollen)

func is_free_for(_player: Node) -> bool:
	if get_parent() is FurnitureBody:
		var body := get_parent() as FurnitureBody
		var used := 0
		for h in body.holds:
			if h.socket_local_node == self or _node_in_path(h.socket_local_node, self):
				used += 1
		return used < max_players
	return true

static func _node_in_path(leaf: Node, ancestor: Node) -> bool:
	var n := leaf
	while n != null:
		if n == ancestor:
			return true
		n = n.get_parent()
	return false
