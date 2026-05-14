extends PathFollow2D

@export var speed: float = 60.0
@export var remove_at_end: bool = true

func _ready():
	set_process(false)

func activate():
	set_process(true)

func _process(delta: float):
	progress += speed * delta
	if progress_ratio >= 1.0:
		if remove_at_end:
			queue_free()
		else:
			set_process(false)
