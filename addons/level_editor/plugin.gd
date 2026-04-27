@tool
extends EditorPlugin

var panel: Control

func _enter_tree():
	if not ProjectSettings.has_setting("game/debug/start_dist"):
		ProjectSettings.set_setting("game/debug/start_dist", 0)
		ProjectSettings.save()

	panel = load("res://addons/level_editor/LevelEditorPanel.gd").new()
	add_control_to_bottom_panel(panel, "Level Editor")

func _exit_tree():
	if panel:
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
