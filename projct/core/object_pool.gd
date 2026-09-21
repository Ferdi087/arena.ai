extends Node
class_name ObjectPool
## Generischer Object-Pool für häufig gebaute/zerstörte Nodes (Decals, FX,
## Verkehr, Loot). Kein Autoload – pro Szene/eigene Instanz.
##
## Rule: gepoolte Nodes implementieren optional pool_reset() (zurücksetzen)
## und pool_hide()/pool_show(). free() wird vermieden -> GC-Druck runter (#24/#74).

@export var scene: PackedScene
@export var prefill: int = 0
@export var max_size: int = 256

var _available: Array[Node] = []
var _in_use: Dictionary[Node, bool] = {}
var _created_total: int = 0

func _ready() -> void:
	for i in prefill:
		_available.append(_create())

func acquire() -> Node:
	var node: Node
	if not _available.is_empty():
		node = _available.pop_back()
	else:
		node = _create()
	if node == null:
		return null
	_in_use[node] = true
	if node is CanvasItem:
		(node as CanvasItem).show()
	elif node is Node3D:
		(node as Node3D).visible = true
	if node.has_method("pool_show"):
		node.call("pool_show")
	return node

func release(node: Node) -> void:
	if not _in_use.has(node):
		push_warning("ObjectPool: release von unbekanntem Node %s" % str(node))
		return
	_in_use.erase(node)
	if node.has_method("pool_hide"):
		node.call("pool_hide")
	if node.has_method("pool_reset"):
		node.call("pool_reset")
	if node is CanvasItem:
		(node as CanvasItem).hide()
	elif node is Node3D:
		(node as Node3D).visible = false
	if _available.size() < max_size:
		_available.append(node)
	else:
		node.queue_free()

func stats() -> Dictionary:
	return {"in_use": _in_use.size(), "available": _available.size(), "created": _created_total}

func _create() -> Node:
	if scene == null:
		push_error("ObjectPool: keine scene gesetzt")
		return null
	var node := scene.instantiate()
	add_child(node)
	_created_total += 1
	return node
