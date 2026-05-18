extends Node2D

func _ready() -> void:
	var anim: AnimationPlayer = $AnimationPlayer
	# Usunęliśmy linię z anim.animation_finished.connect(...)
	anim.play("engine")
