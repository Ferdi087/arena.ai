extends Node
class_name State
## Basisklasse für StateMachine-Einträge. enter() darf payload annehmen
## (Dictionary etc.), exit() muss Aufräumarbeiten übernehmen.

var machine: Node = null
var state_id: StringName = &""

func enter(_payload: Variant = null) -> void:
	pass

func exit() -> void:
	pass

func tick(_delta: float) -> void:
	pass

func physics_tick(_delta: float) -> void:
	pass
