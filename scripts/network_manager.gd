## ============================================================
## network_manager.gd — AutoLoad Singleton
## Handles Host / Join / Single-Player session creation.
## Uses ENetMultiplayerPeer (Godot 4.x built-in networking).
## ============================================================
extends Node

# ── Signals ──────────────────────────────────────────────────
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()

# ── Constants ────────────────────────────────────────────────
const PORT: int = 27015
const MAX_CLIENTS: int = 4

# ── State ────────────────────────────────────────────────────
## Tracks every connected peer id. Server is always id = 1.
var players: Dictionary = {}
var is_single_player: bool = false


# ── Lifecycle ────────────────────────────────────────────────
func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ── Public API ───────────────────────────────────────────────
func host_game() -> Error:
	is_single_player = false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("Failed to create server: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	# Server is always peer_id 1
	players[1] = true
	player_connected.emit(1)
	print("[Network] Hosting on port %d — my id = 1" % PORT)
	return OK


func join_game(address: String) -> Error:
	is_single_player = false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		push_error("Failed to join %s:%d — %s" % [address, PORT, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	print("[Network] Joining %s:%d …" % [address, PORT])
	return OK


func start_single_player() -> void:
	is_single_player = true
	# Use an offline peer so multiplayer API still works locally without network overhead.
	var peer := OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = peer
	players[1] = true
	player_connected.emit(1)
	print("[Network] Single-player mode started (Offline).")


func disconnect_game() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()
	is_single_player = false
	print("[Network] Disconnected.")


# ── Callbacks ────────────────────────────────────────────────
func _on_peer_connected(id: int) -> void:
	players[id] = true
	player_connected.emit(id)
	print("[Network] Peer connected: %d" % id)


func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	player_disconnected.emit(id)
	print("[Network] Peer disconnected: %d" % id)


func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	players[my_id] = true
	connection_succeeded.emit()
	player_connected.emit(my_id)
	print("[Network] Connected to server — my id = %d" % my_id)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connection_failed.emit()
	push_warning("[Network] Connection failed!")


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()
	push_warning("[Network] Server disconnected!")
