extends Node2D

@export var scroll_speed: int = 120
@export var start_dist: int = 0

func _ready():
	_connect_signals(self)
	if OS.is_debug_build() and start_dist > 0:
		position.y = start_dist

func _process(delta: float):
	position.y += float(scroll_speed) * delta

func _connect_signals(node: Node):
	for child in node.get_children():
		if child.has_signal("projectile_spawned"):
			child.projectile_spawned.connect(_on_projectile_spawned)
		_connect_signals(child)

func _on_projectile_spawned(projectile: Node):
	get_parent().add_child(projectile)
