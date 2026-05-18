extends Node2D

func _ready() -> void:
	var anim: AnimationPlayer = $AnimationPlayer
	anim.animation_finished.connect(func(_name): queue_free())
	anim.play("explode")
