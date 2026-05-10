## ============================================================
## pause_menu.gd — Pause Menu Controller
## Handles: Resuming, Quitting, and Disconnecting from Network.
## ============================================================
extends Control

# ── Signals ──────────────────────────────────────────────────
# (Optional) We could emit a signal when resuming, 
# but we'll handle logic directly via main script.

# ── Lifecycle ────────────────────────────────────────────────
func _ready() -> void:
	# Hide by default
	visible = false
	# Ensure this menu works even when the game is paused!
	process_mode = Node.PROCESS_MODE_ALWAYS


# ── Public API ───────────────────────────────────────────────
func open() -> void:
	visible = true
	get_tree().paused = true
	# Capture mouse if needed
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	get_tree().paused = false
	# Release mouse or return to capture depending on gameplay
	# For this game, we might want capture back if in-game
	if not get_parent().get_node("MainMenu").visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ── UI Callbacks ─────────────────────────────────────────────
func _on_resume_button_pressed() -> void:
	close()


func _on_quit_to_menu_button_pressed() -> void:
	# Unpause first to avoid stuck state
	get_tree().paused = false
	visible = false
	
	# Handle network cleanup
	if NetworkManager.multiplayer.multiplayer_peer:
		NetworkManager.disconnect_game()
	
	# Tell Main scene to show menu (via parent reference or signal)
	# In this project, Main is the parent of UI/PauseMenu
	var main = get_tree().current_scene
	if main.has_method("_show_menu"):
		main._show_menu()
		
	# Clean up entities
	main._clear_entities()


func _on_quit_game_button_pressed() -> void:
	get_tree().quit()
