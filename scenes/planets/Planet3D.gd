extends Node2D

@export var move_speed: float = 30.0

func _process(delta: float) -> void:
	position.y += move_speed * delta
	if position.y > 2300.0:
		queue_free()
