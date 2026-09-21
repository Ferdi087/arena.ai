extends Node
class_name Interactable
## Component (Child eines StaticBody/RigidBody/Node3D): macht einen Baum "anklickbar".
## Kein Monolith: Interactable weiß nur ÜBER seine Fähigkeiten – ausführen tun
## Services/RPCs (Türen, Computer, Shops...). #64 Composition over Inheritance.

@export var prompt_text: String = "Benutzen"
@export var action: StringName = &"use"          # wird an den Handler weitergereicht
@export var range_m: float = 3.0
@export var handler: Node                          # muss can_use()/do_use() haben (optional: do_secondary())
@export var hold_to_use: bool = false
@export var one_shot: bool = false                 # nach Benutzung deaktiviert
@export var enabled: bool = true

var _used_once: bool = false

signal interacted(player: Node)

func is_available_for(_player: Node) -> bool:
	if not enabled or (one_shot and _used_once):
		return false
	if handler != null and handler.has_method("can_use"):
		return handler.call("can_use", _player)
	return true

func activate(player: Node) -> void:
	if not is_available_for(player):
		return
	_used_once = true
	interacted.emit(player)
	if handler != null and handler.has_method("do_use"):
		handler.call("do_use", player, action)

func debug_label() -> String:
	return "%s [%s]" % [prompt_text, String(action)]
