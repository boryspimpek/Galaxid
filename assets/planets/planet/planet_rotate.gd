extends Node3D

@export var spin_speed: float = 0.4   # rad/s wokół osi Y

func _process(delta: float) -> void:
	transform = transform.rotated_local(Vector3.UP, spin_speed * delta)
