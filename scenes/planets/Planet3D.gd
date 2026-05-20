extends Node2D

@export var move_speed: float = 30.0
@export var rotation_speed: float = 0.1

@onready var _viewport: SubViewport = $SubViewportContainer/SubViewport

func _process(delta: float) -> void:
	position.y += move_speed * delta
	if position.y > 2300.0:
		queue_free()
	_rotate_planet(delta)

func _rotate_planet(delta: float) -> void:
	if rotation_speed == 0.0:
		return
	for child in _viewport.get_children():
		if child is Node3D:
			child.rotate_y(rotation_speed * delta)
