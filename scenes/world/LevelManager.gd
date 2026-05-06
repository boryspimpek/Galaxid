extends Node2D

@export var scroll_speed: int = 2

func _ready():
	_connect_signals(self)

func _process(_delta):
	position.y += scroll_speed

func _connect_signals(node: Node):
	for child in node.get_children():
		if child.has_signal("projectile_spawned"):
			child.projectile_spawned.connect(_on_projectile_spawned)
		_connect_signals(child)

func _on_projectile_spawned(projectile: Node):
	get_parent().add_child(projectile)
