extends Node2D

## Y w przestrzeni LevelMap (ujemne = nad ekranem startowym).
## Wpisuj wartość z LevelRuler, np. -200 aktywuje gdy scroll osiągnie 200 px.
@export var activation_scroll_y: float = 0.0

var _level_map: Node2D
var _activated := false

func _ready() -> void:
	_level_map = get_parent().get_node_or_null("LevelMap")
	if not _level_map:
		push_warning("Formation: brak węzła 'LevelMap' w rodzicu")
		set_process(false)

func _process(_delta: float) -> void:
	if _level_map.position.y >= -activation_scroll_y:
		_activate_all()

func _activate_all() -> void:
	if _activated:
		return
	_activated = true
	set_process(false)
	for child in get_children():
		if child is Path2D:
			for follow in child.get_children():
				if follow.has_method("activate"):
					follow.activate()
