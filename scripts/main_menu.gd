## ============================================================
## main_menu.gd — Main Menu Controller
## Handles: Hosting, Joining, and Single-Player session startup.
## ============================================================
extends Control

# ── Signals ──────────────────────────────────────────────────
signal host_requested()
signal join_requested(address: String)
signal single_player_requested()

# ── Cached Refs ──────────────────────────────────────────────
@onready var ip_input: LineEdit = $CenterContainer/PanelContainer/VBox/IPInput
@onready var status_label: Label = $CenterContainer/PanelContainer/VBox/StatusLabel

# ── Public API ───────────────────────────────────────────────
func set_status(text: String) -> void:
	if status_label:
		status_label.text = text


func _on_host_button_pressed() -> void:
	host_requested.emit()


func _on_join_button_pressed() -> void:
	var address = ip_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	join_requested.emit(address)


func _on_single_player_button_pressed() -> void:
	single_player_requested.emit()
