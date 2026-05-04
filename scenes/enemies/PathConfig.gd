@tool
extends Path2D

@export var speed: float = 3.0
@export var speed_curve: Curve
# Tylko formacje ustawiają auto_advance = true. Enemy-embedded paths nigdy.
@export var auto_advance: bool = false

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not auto_advance:
		return
	for child in get_children():
		if not child is PathFollow2D:
			continue
		var mult := speed_curve.sample(child.progress_ratio) if speed_curve else 1.0
		child.progress += speed * mult
		if child.progress_ratio >= 1.0:
			var rt = child.get_node_or_null("RemoteTransform2D")
			if rt and rt.remote_path:
				var target = rt.get_node_or_null(rt.remote_path)
				if target and is_instance_valid(target):
					target.queue_free()
