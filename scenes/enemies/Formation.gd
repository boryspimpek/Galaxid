extends Node2D

var _activated := false

func activate_formation() -> void:
	if _activated:
		return
	_activated = true
	reparent(get_tree().current_scene)
	for child in get_children():
		if child is Path2D:
			for follow in child.get_children():
				if follow.has_method("activate"):
					follow.activate()
