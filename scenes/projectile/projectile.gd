extends Area2D

# --- Parametry pocisku (ustawiane przez WeaponSystem) ---
@export var velocity: Vector2 = Vector2.ZERO
@export var damage: int = 3

# --- Wewnętrzne ---
var speed_multiplier: float = 30.0  # Mnożnik prędkości z Tyriana

func _physics_process(delta):
	# Poruszamy pociskiem
	position += velocity * speed_multiplier * delta
	
	# Usuwamy pocisk, gdy wyjdzie poza ekran
	# Marginesy: -50 góra, 800 dół (720 + margines), -50/-50 boki
	if position.y < -50 or position.y > 800 or position.x < -50 or position.x > 1330:
		queue_free()

func _on_area_entered(area):
	# TODO: Obsługa kolizji z wrogami
	pass

func _on_body_entered(body):
	# TODO: Obsługa kolizji z obiektami
	pass
