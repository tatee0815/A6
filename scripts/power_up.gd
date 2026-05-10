## ============================================================
## power_up.gd — Collectible Power-up Item
## Attached to Area3D. Two types: "heal" and "damage_boost".
## Spins, bobs up/down, respawns after pickup.
## ============================================================
extends Area3D

# ── Configuration ────────────────────────────────────────────
@export_enum("heal", "damage_boost") var power_up_type: String = "heal"
@export var heal_amount: int = 50
@export var boost_multiplier: float = 2.0
@export var boost_duration: float = 8.0
@export var respawn_time: float = 15.0

# ── Internal ─────────────────────────────────────────────────
var _base_y: float = 0.0
var _time: float = 0.0
var _is_active: bool = true

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D


func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)
	_apply_visual()


func _process(delta: float) -> void:
	if not _is_active:
		return
	# Spin and bob
	_time += delta
	rotate_y(2.0 * delta)
	position.y = _base_y + sin(_time * 3.0) * 0.3


func _apply_visual() -> void:
	if not mesh:
		return
	var mat := StandardMaterial3D.new()
	mat.metallic = 0.4
	mat.roughness = 0.3
	mat.emission_enabled = true

	match power_up_type:
		"heal":
			mat.albedo_color = Color(0.1, 0.9, 0.3)
			mat.emission = Color(0.1, 0.9, 0.3)
			mat.emission_energy_multiplier = 1.5
			if label:
				label.text = "♥ HEAL"
				label.modulate = Color(0.2, 1, 0.3)
		"damage_boost":
			mat.albedo_color = Color(0.9, 0.3, 0.1)
			mat.emission = Color(0.9, 0.3, 0.1)
			mat.emission_energy_multiplier = 1.5
			if label:
				label.text = "⚡ DAMAGE"
				label.modulate = Color(1, 0.4, 0.1)

	mesh.material_override = mat


func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	if not _is_active:
		return
	# Only players can pick up
	if not body.has_method("heal"):
		return

	# Apply effects on server (will be synced to clients via their own systems)
	match power_up_type:
		"heal":
			body.heal(heal_amount)
		"damage_boost":
			body.apply_damage_boost(boost_multiplier, boost_duration)

	# Sync deactivation to all clients
	_sync_deactivate.rpc()


@rpc("call_local", "reliable")
func _sync_deactivate() -> void:
	_is_active = false
	visible = false
	set_deferred("monitoring", false)
	if multiplayer.is_server():
		await get_tree().create_timer(respawn_time).timeout
		_sync_reactivate.rpc()


@rpc("call_local", "reliable")
func _sync_reactivate() -> void:
	_is_active = true
	visible = true
	set_deferred("monitoring", true)
