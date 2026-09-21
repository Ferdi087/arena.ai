extends Node
## Generic State Machine – wird von BuildMode, JobSite-Phasen, Player-Ragdoll-Flow
## etc. verwendet. Kein Autoload: jede Szene/Instanz besitzt ihre eigene.
##
## States registrieren sich mit eindeutigen IDs; Transitionen feuern exit/enter.

signal state_changed(previous: StringName, current: StringName)

var states: Dictionary[StringName, Node] = {}
var current_id: StringName = &""
var current: Node = null

func add_state(id: StringName, state: Node) -> void:
	assert(state.has_method("enter") and state.has_method("exit"))
	states[id] = state
	if current_id == &"":
		change(id)

func change(id: StringName, payload: Variant = null) -> void:
	if id == current_id:
		return
	if not states.has(id):
		push_warning("StateMachine: unbekannter State '%s'" % id)
		return
	var prev := current_id
	if current != null and current.has_method("exit"):
		current.exit()
	current_id = id
	current = states[id]
	if current.has_method("enter"):
		current.enter(payload)
	state_changed.emit(prev, current_id)

func _process(delta: float) -> void:
	if current != null and current.has_method("tick"):
		current.tick(delta)

func _physics_process(delta: float) -> void:
	if current != null and current.has_method("physics_tick"):
		current.physics_tick(delta)
