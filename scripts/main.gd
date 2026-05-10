## ============================================================
## main.gd — Main Scene Controller
## Handles: Network UI, player spawning, enemy spawning,
##          power-up placement, and game state.
## Attached to the root Node3D of the Main scene.
## ============================================================
extends Node3D

# ── Constants ────────────────────────────────────────────────
const PLAYER_SCENE: PackedScene = preload("res://scenes/player_tank.tscn")
const ENEMY_LIGHT: PackedScene = preload("res://scenes/enemy_light.tscn")
const ENEMY_MEDIUM: PackedScene = preload("res://scenes/enemy_medium.tscn")
const POWER_UP_SCENE: PackedScene = preload("res://scenes/power_up.tscn")

# ── Spawn positions ─────────────────────────────────────────
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(-10, 2, -10),
	Vector3(10, 2, -10),
	Vector3(-10, 2, 10),
	Vector3(10, 2, 10),
]

const ENEMY_SPAWNS: Array[Dictionary] = [
	{"type": "light",  "pos": Vector3(-18, 2, -18)},
	{"type": "light",  "pos": Vector3(18, 2, 18)},
	{"type": "medium", "pos": Vector3(18, 2, -18)},
	{"type": "medium", "pos": Vector3(-18, 2, 18)},
]

const POWERUP_POSITIONS: Array[Dictionary] = [
	{"type": "heal",         "pos": Vector3(0, 1.5, 0)},
	{"type": "damage_boost", "pos": Vector3(-15, 1.5, 15)},
	{"type": "heal",         "pos": Vector3(15, 1.5, -15)},
	{"type": "damage_boost", "pos": Vector3(0, 1.5, 20)},
]

# ── Cached UI refs ──────────────────────────────────────────
@onready var main_menu: Control = $UI/MainMenu
@onready var players_node: Node3D = $Players
@onready var enemies_node: Node3D = $Enemies
@onready var powerups_node: Node3D = $PowerUps
@onready var pause_menu: Control = $UI/PauseMenu

var _spawn_index: int = 0


# ── Lifecycle ────────────────────────────────────────────────
func _ready() -> void:
	# Connect Main Menu signals
	main_menu.host_requested.connect(_on_host_pressed)
	main_menu.join_requested.connect(_on_join_pressed)
	main_menu.single_player_requested.connect(_on_single_player_pressed)

	# Connect network signals
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

	# Setup Mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Configure MultiplayerSpawner for Players
	var spawner: MultiplayerSpawner = $MultiplayerSpawner
	spawner.spawn_path = NodePath("../Players")
	spawner.spawn_function = _spawn_player_for_peer

	# Create Spawner for Enemies
	var enemy_spawner := MultiplayerSpawner.new()
	enemy_spawner.name = "EnemySpawner"
	enemy_spawner.spawn_path = NodePath("../Enemies")
	enemy_spawner.add_spawnable_scene(ENEMY_LIGHT.resource_path)
	enemy_spawner.add_spawnable_scene(ENEMY_MEDIUM.resource_path)
	add_child(enemy_spawner)

	# Create Spawner for PowerUps
	var powerup_spawner := MultiplayerSpawner.new()
	powerup_spawner.name = "PowerUpSpawner"
	powerup_spawner.spawn_path = NodePath("../PowerUps")
	powerup_spawner.add_spawnable_scene(POWER_UP_SCENE.resource_path)
	add_child(powerup_spawner)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # Usually Escape
		if not main_menu.visible:
			if pause_menu.visible:
				pause_menu.close()
			else:
				pause_menu.open()


# ── UI Callbacks ─────────────────────────────────────────────
func _on_host_pressed() -> void:
	var err := NetworkManager.host_game()
	if err == OK:
		main_menu.set_status("Hosting… Waiting for players.")
		_hide_menu()
		# Also spawn enemies & items in host mode
		_spawn_enemies()
		_spawn_powerups()
	else:
		main_menu.set_status("Failed to host: %s" % error_string(err))


func _on_join_pressed(address: String) -> void:
	var err := NetworkManager.join_game(address)
	if err == OK:
		main_menu.set_status("Connecting to %s…" % address)
	else:
		main_menu.set_status("Failed to join: %s" % error_string(err))


func _on_single_player_pressed() -> void:
	NetworkManager.start_single_player()
	_hide_menu()
	# Spawn AI enemies and power-ups
	_spawn_enemies()
	_spawn_powerups()


func _hide_menu() -> void:
	main_menu.visible = false


func _show_menu() -> void:
	main_menu.visible = true
	main_menu.set_status("")


# ── Network Callbacks ────────────────────────────────────────
func _on_player_connected(peer_id: int) -> void:
	# Only the server (host) spawns players
	if multiplayer.is_server():
		_do_spawn(peer_id)


func _on_player_disconnected(peer_id: int) -> void:
	# Remove the player node
	var player_node_name := str(peer_id)
	if players_node.has_node(player_node_name):
		players_node.get_node(player_node_name).queue_free()


func _on_connection_succeeded() -> void:
	_hide_menu()


func _on_connection_failed() -> void:
	main_menu.set_status("Connection failed! Check IP and try again.")


func _on_server_disconnected() -> void:
	_clear_entities()
	_show_menu()
	main_menu.set_status("Server disconnected.")


func _clear_entities() -> void:
	# Clean up all players, enemies, and power-ups
	for child in players_node.get_children():
		child.queue_free()
	for child in enemies_node.get_children():
		child.queue_free()
	for child in powerups_node.get_children():
		child.queue_free()


# ── Player Spawning ──────────────────────────────────────────
func _do_spawn(peer_id: int) -> void:
	# Use MultiplayerSpawner to replicate across all peers
	var spawner: MultiplayerSpawner = $MultiplayerSpawner
	spawner.spawn(peer_id)


func _spawn_player_for_peer(peer_id: int) -> Node:
	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	player.player_id = peer_id
	player.name = str(peer_id)
	# Use position (not global_position) since node isn't in tree yet
	var idx: int = _spawn_index % SPAWN_POINTS.size()
	player.position = SPAWN_POINTS[idx]
	_spawn_index += 1
	return player


# ── Enemy Spawning ───────────────────────────────────────────
func _spawn_enemies() -> void:
	if not multiplayer.is_server():
		return
	for i in ENEMY_SPAWNS.size():
		var data: Dictionary = ENEMY_SPAWNS[i]
		var enemy: CharacterBody3D
		match data["type"]:
			"light":
				enemy = ENEMY_LIGHT.instantiate()
			"medium":
				enemy = ENEMY_MEDIUM.instantiate()
			_:
				enemy = ENEMY_LIGHT.instantiate()
		enemy.name = "Enemy_%d" % i
		enemy.position = data["pos"]
		enemies_node.add_child(enemy)


# ── Power-up Spawning ────────────────────────────────────────
func _spawn_powerups() -> void:
	if not multiplayer.is_server():
		return
	for i in POWERUP_POSITIONS.size():
		var data: Dictionary = POWERUP_POSITIONS[i]
		var pu: Area3D = POWER_UP_SCENE.instantiate()
		pu.name = "PowerUp_%d" % i
		pu.power_up_type = data["type"]
		pu.position = data["pos"]
		powerups_node.add_child(pu)
