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
	var path2d = get_parent()
	if not path2d:
		return
	var formation = path2d.get_parent()
	if formation and formation.has_method("activate_formation"):
		formation.activate_formation()
	else:
		for sibling in path2d.get_children():
			if sibling.has_method("activate"):
				sibling.activate()

func _process(delta: float):
	progress += speed * delta
	if progress_ratio >= 1.0:
		if remove_at_end:
			queue_free()
		set_process(false)
