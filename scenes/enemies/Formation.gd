extends Node2D

## Dołącz do roota każdej formacji z Path2D.
## Aktywuje wszystkie EnemyPath gdy formacja wejdzie w obszar ekranu.
## Pozwala stawiać wrogów z boku (startujących off-screen) tak samo jak resztę mapy.

func _ready():
	var notifier := VisibleOnScreenNotifier2D.new()
	# Szeroki pasek – odpala się niezależnie od pozycji X roota formacji
	notifier.rect = Rect2(-2000, -10, 10000, 20)
	add_child(notifier)
	notifier.screen_entered.connect(activate_formation)

func activate_formation():
	for child in get_children():
		if child is Path2D:
			for follower in child.get_children():
				if follower.has_method("activate"):
					follower.activate()
