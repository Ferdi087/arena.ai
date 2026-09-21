extends Node
class_name ChunkManager
## Simulations-Stufen pro Distanz (#75/#76/#130) – für die Slice als Distanz-
## Regler über Furniture/NPC-Gruppen; später als GridMap-Chunk-Streaming erweiterbar.
## Stufen: FULL (sim), REDUCED (Sleep + nur grobe Kollision), DORMANT (freeze).

const FULL_R := 45.0
const SIM_R := 90.0
const TICK_EVERY := 0.5

var _accum: float = 0.0

func _process(delta: float) -> void:
	_accum += delta
	if _accum < TICK_EVERY:
		return
	_accum = 0.0
	var center := _focus_pos()
	if center == Vector3.INF:
		return
	_update_bodies(center)

func _focus_pos() -> Vector3:
	for p in get_tree().get_nodes_in_group("players"):
		var pl := p as Player
		if pl != null and pl.is_authority():
			return pl.global_position
	return Vector3.INF

func _update_bodies(center: Vector3) -> void:
	for node in get_tree().get_nodes_in_group("furniture"):
		var fb := node as FurnitureBody
		if fb == null:
			continue
		if fb.locked_in_cargo or fb.is_held():
			continue
		var d := fb.global_position.distance_to(center)
		if d > SIM_R:
			if not fb.freeze:
				fb.freeze = true
				fb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		elif d > FULL_R:
			if not fb.sleeping:
				fb.freeze = false
				fb.sleeping_threshold_linear = 0.8
		else:
			fb.freeze = false
			fb.sleeping_threshold_linear = 0.25
	for node in get_tree().get_nodes_in_group("npcs"):
		var agent := node as Node3D
		if agent == null:
			continue
		agent.visible = agent.global_position.distance_to(center) < SIM_R
		agent.set_physics_process(agent.global_position.distance_to(center) < FULL_R)
