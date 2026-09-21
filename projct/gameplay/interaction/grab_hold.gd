extends RefCounted
class_name GrabHold
## Ein aktiver Halt: "Player P greift am Körper LOKALEN Punkt grip_local und
## will ihn am WELTPUNKT socket_global haben". Mehrere Holds = Co-Op-Lift.
## Rein Daten – der Solver lebt in FurnitureBody._integrate_forces.

var player: Node = null
var grip_local: Vector3 = Vector3.ZERO      # Gripping Punkt im Body-Localspace
var socket_local_node: Node3D = null        # HoldSocket am Spieler (GrabSocket)
var socket_global: Vector3 = Vector3.ZERO   # gecached pro Physik-Tick
var twist_delta: float = 0.0                # angeforderter Roll/Yaw (Q/E)
var strength: float = 1.0                   # 1.0 normaler Spieler
var network_id: int = 1                     # Peer des Halters (Authority-Check)

func update_socket() -> void:
	if socket_local_node != null and is_instance_valid(socket_local_node):
		socket_global = socket_local_node.global_position

func _init(p_player: Node = null, p_grip: Vector3 = Vector3.ZERO, p_socket: Node3D = null, p_strength: float = 1.0, p_peer: int = 1) -> void:
	player = p_player
	grip_local = p_grip
	socket_local_node = p_socket
	strength = p_strength
	network_id = p_peer
	update_socket()
