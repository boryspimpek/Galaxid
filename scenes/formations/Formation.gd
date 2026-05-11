extends Node2D

# Formacja: jeden VisibleOnScreenNotifier2D na cały Node2D, aktywuje wszystkich
# wrogów jednocześnie. Disconnect-uje wewnętrzne notifery każdego wroga.

func _ready() -> void:
	for child in get_children():
		if not child.is_in_group("enemies"):
			continue
		var notifier := child.get_node_or_null("VisibleOnScreenNotifier2D")
		if notifier:
			if notifier.screen_entered.is_connected(child._on_screen_entered):
				notifier.screen_entered.disconnect(child._on_screen_entered)
			if notifier.screen_exited.is_connected(child._on_screen_exited):
				notifier.screen_exited.disconnect(child._on_screen_exited)

	$VisibleOnScreenNotifier2D.screen_entered.connect(_on_screen_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)

func _on_screen_entered() -> void:
	for child in get_children():
		if child.is_in_group("enemies"):
			child.set_process(true)

func _on_screen_exited() -> void:
	queue_free()
