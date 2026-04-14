extends Area2D

# --- Parametry pocisku (ustawiane przez WeaponSystem) ---
@export var velocity: Vector2 = Vector2.ZERO
@export var acceleration: Vector2 = Vector2.ZERO  # Przyspieszenie po wystrzeleniu
@export var damage: int = 3
@export var lifetime: int = 0  # Czas życia (del z patterns)
@export var shot_graphic: int = 0  # ID grafiki (sg z patterns)

# --- Wewnętrzne ---
var speed_multiplier: float = 30.0  # Mnożnik prędkości z Tyriana
var lifetime_timer: float = 0.0

func _physics_process(delta):
	# Przyspieszenie velocity
	velocity += acceleration * delta
	
	# Poruszamy pociskiem
	position += velocity * speed_multiplier * delta
	
	# Obsługa czasu życia (jeśli lifetime > 0)
	if lifetime > 0:
		lifetime_timer += delta * 60  # delta * 60 dla klatek
		if lifetime_timer >= lifetime:
			queue_free()
			return
	
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
