## ============================================================
## enemy_base.gd — Base Enemy AI Controller
## Attached to CharacterBody3D. Uses NavigationAgent3D to
## chase the nearest player and shoot.
## Subclassed by Light / Medium tank variants via exported vars.
## ============================================================
extends CharacterBody3D

# ── Tuning (overridden by variants) ─────────────────────────
@export var move_speed: float = 5.0
@export var rotation_speed: float = 2.0
@export var max_health: int = 80
@export var fire_rate: float = 1.5        # seconds between shots
@export var attack_range: float = 18.0
@export var detection_range: float = 25.0
@export var bullet_damage: float = 15.0
@export var enemy_type: String = "Base"

# ── State ────────────────────────────────────────────────────
enum State { IDLE, CHASE, ATTACK }
var current_state: State = State.IDLE
var health: int = 80
var can_shoot: bool = true
var target_player: Node3D = null
var is_dead: bool = false

const GRAVITY: float = 20.0
const BULLET_SCENE: PackedScene = preload("res://scenes/bullet.tscn")

# ── Cached refs ──────────────────────────────────────────────
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var body_mesh: MeshInstance3D = $Body
@onready var turret: Node3D = $Turret
@onready var bullet_spawn: Marker3D = $Turret/Barrel/BulletSpawn
@onready var health_bar_3d: Sprite3D = $HealthBar3D
@onready var health_bar_fill: Sprite3D = $HealthBar3D/Fill
@onready var detection_timer: Timer = $DetectionTimer
@onready var type_label: Label3D = $TypeLabel


func _enter_tree() -> void:
	_setup_multiplayer_synchronizer()


func _ready() -> void:
	health = max_health
	# NavigationAgent3D settings
	nav_agent.path_desired_distance = 2.0
	nav_agent.target_desired_distance = 2.0
	nav_agent.max_speed = move_speed

	# Timer to periodically scan for players
	detection_timer.wait_time = 0.5
	detection_timer.timeout.connect(_scan_for_target)
	detection_timer.start()

	if type_label:
		type_label.text = enemy_type

	_update_health_bar()


func _setup_multiplayer_synchronizer() -> void:
	var sync := MultiplayerSynchronizer.new()
	sync.name = "MultiplayerSynchronizer"
	
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	# Add properties to sync
	config.add_property(".:position")
	config.add_property(".:rotation")
	config.add_property(".:health")
	config.add_property(".:visible")
	
	sync.replication_config = config
	# Enemies are always controlled by the server
	sync.set_multiplayer_authority(1)
	add_child(sync)


func _physics_process(delta: float) -> void:
	if not multiplayer.multiplayer_peer:
		return
	# Only process AI on the server (or in single player)
	if not multiplayer.is_server():
		_update_health_bar()
		return
	if is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)

	move_and_slide()
	_update_health_bar()


# ── State: IDLE ──────────────────────────────────────────────
func _state_idle(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	# Transition: found a target → CHASE
	if target_player and is_instance_valid(target_player):
		current_state = State.CHASE


# ── State: CHASE ─────────────────────────────────────────────
func _state_chase(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		current_state = State.IDLE
		return

	# Check if target is dead
	if target_player.get("is_dead") == true:
		target_player = null
		current_state = State.IDLE
		return

	var dist: float = global_position.distance_to(target_player.global_position)

	# Within attack range → ATTACK
	if dist <= attack_range:
		current_state = State.ATTACK
		return

	# Navigate towards target
	nav_agent.target_position = target_player.global_position
	if nav_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var direction: Vector3 = (next_pos - global_position).normalized()
	
	# Fallback: if navigation isn't working, move directly towards player
	if direction.length() < 0.1:
		direction = (target_player.global_position - global_position).normalized()
	
	direction.y = 0.0

	# Rotate towards movement direction (Godot forward is -Z)
	if direction.length() > 0.01:
		var target_angle: float = atan2(direction.x, direction.z) + PI
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed


# ── State: ATTACK ────────────────────────────────────────────
func _state_attack(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		current_state = State.IDLE
		return

	if target_player.get("is_dead") == true:
		target_player = null
		current_state = State.IDLE
		return

	var dist: float = global_position.distance_to(target_player.global_position)

	# Out of attack range → CHASE
	if dist > attack_range * 1.2:
		current_state = State.CHASE
		return

	# Face the target (Godot forward is -Z)
	var to_target: Vector3 = (target_player.global_position - global_position).normalized()
	to_target.y = 0.0
	if to_target.length() > 0.01:
		var target_angle: float = atan2(to_target.x, to_target.z) + PI
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * 2.0 * delta)

	# Stop moving while attacking
	velocity.x = 0.0
	velocity.z = 0.0

	# Shoot
	if can_shoot:
		_shoot()


# ── Combat ───────────────────────────────────────────────────
func _shoot() -> void:
	can_shoot = false
	# Spawn bullet on all peers
	_spawn_bullet.rpc()
	# Cooldown
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true


@rpc("any_peer", "call_local", "reliable")
func _spawn_bullet() -> void:
	var bullet: Node = BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	bullet.global_position = bullet_spawn.global_position
	bullet.direction = -bullet_spawn.global_transform.basis.z
	bullet.shooter_id = -1  # Negative ID = enemy
	bullet.damage = bullet_damage


func take_damage(amount: float, attacker_id: int = -1) -> void:
	# Only the server processes damage
	if not multiplayer.is_server():
		return
	if is_dead:
		return
	health -= int(amount)
	health = max(health, 0)
	
	if health <= 0:
		_die(attacker_id)


func _die(attacker_id: int = -1) -> void:
	if not multiplayer.is_server():
		return
	is_dead = true
	visible = false
	
	# Reward the attacker if it's a player
	if attacker_id != -1:
		var players = get_tree().get_nodes_in_group("players")
		for p in players:
			if p.get("player_id") == attacker_id:
				p.add_score(1)
				break
	# Respawn after 8 seconds
	await get_tree().create_timer(8.0).timeout
	_respawn()


func _respawn() -> void:
	if not multiplayer.is_server():
		return
	health = max_health
	is_dead = false
	visible = true
	position = Vector3(randf_range(-20, 20), 2.0, randf_range(-20, 20))
	current_state = State.IDLE
	target_player = null


# ── Detection ────────────────────────────────────────────────
func _scan_for_target() -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return

	var players_node: Node = get_tree().current_scene.get_node_or_null("Players")
	if not players_node:
		return

	var best_dist: float = detection_range
	var best_target: Node3D = null

	for player in players_node.get_children():
		if not is_instance_valid(player):
			continue
		if player.get("is_dead") == true:
			continue
		var dist: float = global_position.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best_target = player

	target_player = best_target
	if target_player and current_state == State.IDLE:
		current_state = State.CHASE


# ── Health Bar ───────────────────────────────────────────────
func _update_health_bar() -> void:
	if health_bar_fill:
		var ratio: float = float(health) / float(max_health)
		health_bar_fill.scale.x = ratio
		# Color: green → yellow → red
		if ratio > 0.5:
			health_bar_fill.modulate = Color(0.2, 0.9, 0.2)
		elif ratio > 0.25:
			health_bar_fill.modulate = Color(0.9, 0.9, 0.2)
		else:
			health_bar_fill.modulate = Color(0.9, 0.2, 0.2)


# Add this to ensure client updates health bar when health is synced
func _process(_delta: float) -> void:
	if not multiplayer.multiplayer_peer:
		return
	if not multiplayer.is_server():
		_update_health_bar()
