extends PathFollow2D

@export var speed: float = 60.0
@export var remove_at_end: bool = true

var _activated := false

func _ready():
	set_process(false)

func activate():
	if _activated:
		return
	_activated = true
	set_process(true)
	if get_parent():
		for sibling in get_parent().get_children():
			if sibling.has_method("activate"):
				sibling.activate()

func _process(delta: float):
	progress += speed * delta
	if progress_ratio >= 1.0:
		if remove_at_end:
			queue_free()
		else:
			set_process(false)
