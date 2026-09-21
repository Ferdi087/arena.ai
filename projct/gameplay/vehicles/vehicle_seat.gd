extends Node3D
class_name VehicleSeat
## Sitz = Interactable-Handler: rein (E), aus (E beim Fahren/F). #62/#92.

@export var seat_index: int = 0
@export var vehicle: VehicleController = null

func _ready() -> void:
	if get_node_or_null("Interact") == null:
		var it := Interactable.new()
		it.name = "Interact"
		it.prompt_text = "Einsteigen"
		it.action = &"enter_vehicle"
		it.handler = self
		add_child(it)

func can_use(player: Node) -> bool:
	if vehicle == null:
		return false
	if seat_index == 0:
		return vehicle.driver == null
	return vehicle.passenger == null

func do_use(_player: Node, action: StringName) -> void:
	match action:
		&"enter_vehicle":
			_enter(_player as Player)

func _enter(player: Player) -> void:
	if vehicle == null:
		return
	if seat_index == 0:
		vehicle.take_control(player)
		if Net.is_online():
			claim_driver.rpc_id(Net.server_peer_id(), get_path(), player.network_peer_id)
		if player.get_rig() != null:
			player.get_rig().enter_vehicle_mode(vehicle, seat_index)
	else:
		vehicle.passenger = player
		if Net.is_online():
			claim_passenger.rpc_id(Net.server_peer_id(), get_path(), player.network_peer_id)
	player.enter_vehicle(vehicle, seat_index)

@rpc("any_peer", "call_remote", "reliable")
func claim_driver(_seat_path: NodePath, _peer: int) -> void:
	if Net.is_authority() and vehicle != null:
		var sender := multiplayer.get_remote_sender_id()
		var p := Net.get_player_by_peer(sender) as Player
		if p != null and vehicle.driver == null:
			vehicle.take_control(p)

@rpc("any_peer", "call_remote", "reliable")
func claim_passenger(_seat_path: NodePath, _peer: int) -> void:
	if Net.is_authority() and vehicle != null:
		var sender := multiplayer.get_remote_sender_id()
		var p := Net.get_player_by_peer(sender) as Player
		if p != null and vehicle.passenger == null:
			vehicle.passenger = p

func exit_prompt() -> String:
	return "Aussteigen [F]" if seat_index == 0 else "Platz verlassen"
