extends Node
## Network Manager (Autoload "Net") – High-Level-Multiplayer-Fundament (#4/#114).
##
## Modi: OFFLINE (Singleplayer – identischer Codepfad wie HOST allein!),
##       HOST (listen-server, ENet), CLIENT, SPLIT_LOCAL (lokaler Co-op).
##
## Prinzipien:
##  * Server-Authority für Physik-Relevanz: Grabs/Release/Spawn/Remove/Score.
##  * Clients senden nur INTENTEN über *request*-RPCs; Server validiert Peer &
##    Node-Zugehörigkeit (#103).
##  * MultiplayerSpawner: Welt-Szene registriert spawn_function hier (siehe
##    world_root.gd); Spieler-Spawns durch Host; Synchronizer-Replikation der
##    Player-/Furniture-Transforms; Interpolation via SceneReplicationConfig
##    PROPERTY_MODE_ALWAYS + replication_interval.
##  * Kein dedizierter Service nötig; Lobby/Session-Code vorbereitet:
##    lobby_state() liefert strukturierbares Dictionary für spätere UIs.

enum Mode { OFFLINE, HOST, CLIENT, SPLIT_LOCAL }

const DEFAULT_PORT := 24571
const MAX_PLAYERS := 4

var mode: int = Mode.OFFLINE
var session_name: String = "HAUL-O-SESSION"
var _players_by_peer: Dictionary[int, Player] = {}
var _next_split_index: int = 0

signal connection_failed(reason: String)
signal player_spawned(peer_id: int, player: Player)

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# ---------------------------------------------------------------- Session --

func host_game(max_players: int = MAX_PLAYERS, port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, clampi(max_players, 2, MAX_PLAYERS))
	if err != OK:
		connection_failed.emit("Port %d belegt/unavailable (%s)" % [port, error_string(err)])
		return false
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	Game.local_coop_players = 1
	return true

func join_game(ip: String, port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	if peer.get_connection_state() == ENetMultiplayerPeer.CONNECTION_CONNECTING or peer.get_connection_state() == ENetMultiplayerPeer.CONNECTION_CONNECTED:
		multiplayer.multiplayer_peer = peer
		mode = Mode.CLIENT
		return true
	connection_failed.emit("Konnte %s:%d nicht erreichen" % [ip, port])
	return false

func start_local_coop(players: int) -> void:
	mode = Mode.SPLIT_LOCAL
	Game.local_coop_players = clampi(players, 1, 2)
	multiplayer.multiplayer_peer = null  # bewusst offline – Splitscreen braucht kein Networking (#4)

func shutdown() -> void:
	multiplayer.multiplayer_peer = null
	mode = Mode.OFFLINE

func is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and mode != Mode.SPLIT_LOCAL

func server_peer_id() -> int:
	return 1

func is_authority() -> bool:
	return not is_online() or multiplayer.is_server()

func is_authority_player() -> bool:
	return is_authority()

func my_peer_id() -> int:
	if not is_online():
		return 1
	return multiplayer.get_unique_id()

# ----------------------------------------------------------------- Players --

func register_player(peer_id: int, player: Player) -> void:
	_players_by_peer[peer_id] = player
	if not player.tree_exiting.is_connected(_on_player_tree_exiting.bind(peer_id)):
		player.tree_exiting.connect(_on_player_tree_exiting.bind(peer_id))
	EventBus.player_joined.emit(peer_id)

func unregister_player(peer_id: int) -> void:
	_players_by_peer.erase(peer_id)

func get_player_by_peer(peer_id: int) -> Node:
	return _players_by_peer.get(peer_id)

func all_players() -> Array:
	return _players_by_peer.values()

func _on_player_tree_exiting(peer_id: int) -> void:
	_players_by_peer.erase(peer_id)

# ---------------------------------------------------------------- Events --

func _on_peer_connected(peer_id: int) -> void:
	if mode != Mode.HOST:
		return
	# Host spawned einen Player pro Peer (world_root/Spawner hookt das).
	_spawn_player_for_peer.rpc_id(peer_id, peer_id)
	world_notify_player_joined.rpc(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	world_notify_player_left.rpc(peer_id)

@rpc("authority", "call_local", "reliable")
func world_notify_player_joined(peer_id: int) -> void:
	## Welt-Szene (welche auch immer gerade live ist) reacts.
	for node in get_tree().get_nodes_in_group("world"):
		if node.has_method("on_player_joined"):
			node.call("on_player_joined", peer_id)

@rpc("authority", "call_local", "reliable")
func world_notify_player_left(peer_id: int) -> void:
	EventBus.player_left.emit(peer_id)
	for node in get_tree().get_nodes_in_group("world"):
		if node.has_method("on_player_left"):
			node.call("on_player_left", peer_id)

@rpc("authority", "call_remote", "reliable")
func _spawn_player_for_peer(_peer_id: int, target_peer: int) -> void:
	# Realer Spawn-Pfad: HOST instanziiert über den MultiplayerSpawner der
	# Welt-Szene (spawn_function in world_root.gd). Clients bekommen den
	# Spawn automatisch vom Spawner – dieser RPC sagt der WELT nur Bescheid,
	# dass sie bei Bedarf request_player_spawn(target) auslösen soll.
	for n in get_tree().get_nodes_in_group("world"):
		if n.has_method("request_player_spawn"):
			n.call("request_player_spawn", target_peer)

# ---------------------------------------------------------------- Lobby API --

func lobby_state() -> Dictionary:
	return {
		"mode": mode,
		"session": session_name,
		"players": _players_by_peer.keys(),
		"peers": multiplayer.get_peers().size() if is_online() else 0,
	}
