## ============================================================
## player_tank.gd — Player Tank Controller
## Attached to the root CharacterBody3D of the Player scene.
## Handles: movement, turret rotation, shooting, health,
##          multiplayer authority, and the Cheat (God-Mode).
## ============================================================
extends CharacterBody3D

# ── Exports (set per-instance by spawner) ────────────────────
@export var player_id: int = 1

# ── Movement tuning ─────────────────────────────────────────
const MOVE_SPEED: float = 10.0
const ROTATION_SPEED: float = 2.5
const GRAVITY: float = 20.0

# ── Combat ───────────────────────────────────────────────────
var health: int = 100
var max_health: int = 100
var is_dead: bool = false
var can_shoot: bool = true
var shoot_cooldown: float = 0.4
var damage_boost: float = 1.0

# ── Cheat ────────────────────────────────────────────────────
var is_god_mode: bool = false
var cheat_speed_mult: float = 1.0

# ── Cached refs ──────────────────────────────────────────────
@onready var turret: Node3D = $Turret
@onready var bullet_spawn: Marker3D = $Turret/Barrel/BulletSpawn
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var health_bar: ProgressBar = $HUD/HealthBar
@onready var health_label: Label = $HUD/HealthContainer/HealthLabel
@onready var cheat_label: Label = $HUD/CheatLabel
@onready var name_label: Label3D = $NameLabel

const BULLET_SCENE: PackedScene = preload("res://scenes/bullet.tscn")

# ── Colors for different players ─────────────────────────────
const PLAYER_COLORS: Array[Color] = [
	Color(0.2, 0.6, 0.2),   # Green
	Color(0.2, 0.3, 0.7),   # Blue
	Color(0.7, 0.2, 0.2),   # Red
	Color(0.7, 0.6, 0.1),   # Yellow
]


# ── Lifecycle ────────────────────────────────────────────────
func _ready() -> void:
	# Spawner sets the node name to the peer_id string
	var id_from_name := name.to_int()
	if id_from_name > 0:
		player_id = id_from_name
	
	# Set multiplayer authority to the owning player
	set_multiplayer_authority(player_id)

	# Name tag
	if name_label:
		name_label.text = "Player %d" % player_id

	# Camera & HUD only for the local player
	if is_multiplayer_authority():
		camera.make_current()
		$HUD.visible = true
	else:
		$HUD.visible = false

	# Assign a color based on player id
	_apply_tank_color()
	_update_hud()
	_setup_sync_properties()


func _setup_sync_properties() -> void:
	# Add additional properties to the existing synchronizer
	var sync := $MultiplayerSynchronizer
	if sync and sync.replication_config:
		var config: SceneReplicationConfig = sync.replication_config
		# Turret rotation (Vector3)
		if not config.has_property("Turret:rotation"):
			config.add_property("Turret:rotation")
		# Health (int)
		if not config.has_property(".:health"):
			config.add_property(".:health")


func _physics_process(delta: float) -> void:
	# Only the authority processes input
	if not is_multiplayer_authority():
		return
	if is_dead:
		return

	# ── Gravity ──
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	# ── Rotation (A / D) ──
	var rot_input: float = 0.0
	if Input.is_action_pressed("turn_left"):
		rot_input += 1.0
	if Input.is_action_pressed("turn_right"):
		rot_input -= 1.0
	rotate_y(rot_input * ROTATION_SPEED * cheat_speed_mult * delta)

	# ── Forward / Backward (W / S) ──
	var move_input: float = 0.0
	if Input.is_action_pressed("move_forward"):
		move_input += 1.0
	if Input.is_action_pressed("move_backward"):
		move_input -= 1.0
	var forward: Vector3 = -transform.basis.z
	velocity.x = forward.x * move_input * MOVE_SPEED * cheat_speed_mult
	velocity.z = forward.z * move_input * MOVE_SPEED * cheat_speed_mult

	move_and_slide()

	# ── Turret Rotation (Q / E) ──
	var turret_rot: float = 0.0
	if Input.is_key_pressed(KEY_Q):
		turret_rot += 1.0
	if Input.is_key_pressed(KEY_E):
		turret_rot -= 1.0
	turret.rotate_y(turret_rot * ROTATION_SPEED * delta)

	# ── Shooting (Space) ──
	if Input.is_action_just_pressed("shoot") and can_shoot:
		_request_shoot.rpc()
		_start_cooldown()

	# ── Cheat Toggle (C) ──
	if Input.is_action_just_pressed("toggle_cheat"):
		is_god_mode = !is_god_mode
		cheat_speed_mult = 2.0 if is_god_mode else 1.0

	_update_hud()


# ── Shooting ─────────────────────────────────────────────────
@rpc("any_peer", "call_local", "reliable")
func _request_shoot() -> void:
	# Only the owner of this tank can shoot
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority() and multiplayer.get_remote_sender_id() != 0:
		# If server receives from someone not the authority, ignore
		if multiplayer.is_server() and multiplayer.get_remote_sender_id() != get_multiplayer_authority():
			return

	var bullet: Node = BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	bullet.global_position = bullet_spawn.global_position
	bullet.global_transform.basis = bullet_spawn.global_transform.basis
	bullet.direction = -bullet_spawn.global_transform.basis.z
	bullet.shooter_id = player_id
	bullet.damage = 25.0 * damage_boost


func _start_cooldown() -> void:
	can_shoot = false
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true


# ── Damage & Death ───────────────────────────────────────────
func apply_damage(amount: float, _attacker_id: int) -> void:
	# Only the server processes damage
	if not multiplayer.is_server():
		return
	if is_god_mode or is_dead:
		return
	
	health -= int(amount)
	health = max(health, 0)
	
	if health <= 0:
		_die()


func _die() -> void:
	# Server initiates death
	_die_sync.rpc()


@rpc("call_local", "reliable")
func _die_sync() -> void:
	is_dead = true
	visible = false
	# Only the authority (owning player) handles respawn timer
	if is_multiplayer_authority():
		await get_tree().create_timer(3.0).timeout
		_respawn_request.rpc_id(1)


@rpc("any_peer", "reliable")
func _respawn_request() -> void:
	# Server handles respawn
	if not multiplayer.is_server():
		return
	_respawn_sync.rpc()


@rpc("call_local", "reliable")
func _respawn_sync() -> void:
	health = max_health
	is_dead = false
	visible = true
	if is_multiplayer_authority():
		position = Vector3(randf_range(-12, 12), 2.0, randf_range(-12, 12))
	_update_hud()


# ── Heal / Boost (called by power-ups in Phase 2) ───────────
func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	_update_hud()


func apply_damage_boost(mult: float, duration: float) -> void:
	damage_boost = mult
	await get_tree().create_timer(duration).timeout
	damage_boost = 1.0


# ── Visuals ──────────────────────────────────────────────────
func _apply_tank_color() -> void:
	var color_idx: int = (player_id - 1) % PLAYER_COLORS.size()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLAYER_COLORS[color_idx]
	mat.metallic = 0.3
	mat.roughness = 0.6
	# Apply to body and turret meshes
	if has_node("Body"):
		$Body.material_override = mat
	if has_node("Turret/TurretMesh"):
		$Turret/TurretMesh.material_override = mat
	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = PLAYER_COLORS[color_idx].darkened(0.3)
	barrel_mat.metallic = 0.5
	barrel_mat.roughness = 0.4
	if has_node("Turret/Barrel/BarrelMesh"):
		$Turret/Barrel/BarrelMesh.material_override = barrel_mat


func _update_hud() -> void:
	if not is_multiplayer_authority():
		return
	if health_bar:
		health_bar.value = float(health) / float(max_health) * 100.0
	if health_label:
		health_label.text = "%d / %d" % [health, max_health]
	if cheat_label:
		if is_god_mode:
			cheat_label.text = "[ GOD MODE + SPEED HACK ]"
			cheat_label.modulate = Color(1, 0.2, 0.2)
		else:
			cheat_label.text = ""
