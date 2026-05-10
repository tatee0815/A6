## ============================================================
## bullet.gd — Projectile Logic
## Attached to the root Area3D of the Bullet scene.
## Moves forward, detects hits, applies damage, self-destructs.
## ============================================================
extends Area3D

# ── Properties (set by the shooter before adding to tree) ────
var direction: Vector3 = Vector3.FORWARD
var speed: float = 30.0
var damage: float = 25.0
var shooter_id: int = -1
var lifetime: float = 3.0

# ── Internal ─────────────────────────────────────────────────
var _timer: float = 0.0


func _ready() -> void:
	# Connect the body_entered signal for hit detection
	body_entered.connect(_on_body_entered)
	# Enable contact monitoring
	monitoring = true
	monitorable = false


func _physics_process(delta: float) -> void:
	# Calculate next position
	var step: Vector3 = direction.normalized() * speed * delta
	var next_pos: Vector3 = global_position + step
	
	# ── Continuous Collision Detection (Raycast check) ──
	# We perform a quick raycast to see if we'll hit something between here and next_pos
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, next_pos)
	query.collision_mask = collision_mask
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	if result:
		# We hit something! Move to the hit position and trigger collision
		global_position = result.position
		_on_body_entered(result.collider)
		return

	# No hit, move normally
	global_position = next_pos
	
	# Self-destruct after lifetime expires
	_timer += delta
	if _timer >= lifetime:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		# Hit environment (walls, ground) — destroy bullet
		queue_free()
		return

	# ── Hit a Player Tank ──
	if body.has_method("apply_damage"):
		# Don't hit the shooter
		if body.get("player_id") == shooter_id:
			return
		
		# On server, apply damage
		if multiplayer.is_server() or NetworkManager.is_single_player:
			body.apply_damage(damage, shooter_id)
		
		# Always destroy bullet after hitting a target
		queue_free()
		return

	# ── Hit an Enemy Tank ──
	if body.has_method("take_damage"):
		# Don't let enemies damage other enemies (shooter_id < 0)
		if shooter_id < 0:
			# Still destroy the bullet so it doesn't pass through
			queue_free()
			return
		
		if multiplayer.is_server() or NetworkManager.is_single_player:
			body.take_damage(damage, shooter_id)
		
		queue_free()
		return

	# Fallback destroy
	queue_free()
