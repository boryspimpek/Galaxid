extends Area2D

var velocity = Vector2.ZERO
var damage = 3 # To docelowo wpadnie z Twojego XML (atrybut attack)

func _physics_process(delta):
	# Poruszamy pociskiem (30 fps to baza Tyriana, Godot ma 60)
	position += velocity * 30 * delta
	
	# Usuwamy pocisk, gdy wyjdzie poza ekran - zaktualizowane dla 1280x720
	if position.y < -50 or position.y > 800:  # 300 -> 800 (720 + margines)
		queue_free()
