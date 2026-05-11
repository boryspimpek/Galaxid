extends Node2D

# Formacja: jeden VisibleOnScreenNotifier2D aktywuje wszystkich wrogów jednocześnie.
# Każdy wróg sam się usuwa przez własny screen_exited. Formacja usuwa się gdy
# ostatni wróg zniknie.

var _enemy_count: int = 0

func _ready() -> void:
	for child in get_children():
		if not child.is_in_group("enemies"):
			continue
		_enemy_count += 1
		child.tree_exiting.connect(_on_enemy_exiting)
		var notifier := child.get_node_or_null("VisibleOnScreenNotifier2D")
		if notifier and notifier.screen_entered.is_connected(child._on_screen_entered):
			notifier.screen_entered.disconnect(child._on_screen_entered)

	$VisibleOnScreenNotifier2D.screen_entered.connect(_on_screen_entered)

func _on_screen_entered() -> void:
	for child in get_children():
		if child.is_in_group("enemies"):
			child.set_process(true)

func _on_enemy_exiting() -> void:
	_enemy_count -= 1
	if _enemy_count <= 0:
		queue_free()
