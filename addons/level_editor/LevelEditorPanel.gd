@tool
extends Control

const SETTING = "game/debug/start_dist"

var spin_box: SpinBox

func _ready():
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hbox)

	var label = Label.new()
	label.text = "Start from dist:"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)

	spin_box = SpinBox.new()
	spin_box.min_value = 0
	spin_box.max_value = 99999
	spin_box.step = 10
	spin_box.value = ProjectSettings.get_setting(SETTING, 0)
	spin_box.custom_minimum_size.x = 120
	hbox.add_child(spin_box)

	var play_from = Button.new()
	play_from.text = "▶ Play from dist"
	play_from.pressed.connect(_on_play_from)
	hbox.add_child(play_from)

	var play_start = Button.new()
	play_start.text = "▶ Play from start"
	play_start.pressed.connect(_on_play_start)
	hbox.add_child(play_start)

func _on_play_from():
	ProjectSettings.set_setting(SETTING, int(spin_box.value))
	ProjectSettings.save()
	EditorInterface.play_main_scene()

func _on_play_start():
	ProjectSettings.set_setting(SETTING, 0)
	ProjectSettings.save()
	EditorInterface.play_main_scene()
