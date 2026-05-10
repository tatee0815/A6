## ============================================================
## bullet.gd — Projectile Logic
## Attached to the root Area3D of the Bullet scene.
## Moves forward, detects hits, applies damage, self-destructs.
## ============================================================
extends Area3D

# ── Properties (set by the shooter before adding to tree) ────
var direction: Vector3 = Vector3.FORWARD
var speed: float = 40.0
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
	# Move the bullet forward
	global_position += direction.normalized() * speed * delta
	# Self-destruct after lifetime expires
	_timer += delta
	if _timer >= lifetime:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		# Hit environment — just destroy bullet
		queue_free()
		return

	# ── Hit a Player Tank ──
	if body.has_method("apply_damage"):
		# Don't hit the shooter (player bullets)
		if body.get("player_id") == shooter_id:
			return
		if multiplayer.is_server() or NetworkManager.is_single_player:
			body.apply_damage(damage, shooter_id)
		queue_free()
		return

	# ── Hit an Enemy Tank ──
	if body.has_method("take_damage"):
		# Don't let enemies damage other enemies (shooter_id < 0 = enemy)
		if shooter_id < 0:
			return
		if multiplayer.is_server() or NetworkManager.is_single_player:
			body.take_damage(damage)
		queue_free()
		return

	queue_free()
