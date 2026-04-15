extends Area2D

# Stałe przeliczeniowe
const TYRIAN_FPS = 15.0
const SCALE_X = 1280.0 / 320.0   # = 4.0
const SCALE_Y = 720.0 / 200.0   # = 3.6

# Parametry pocisku
var velocity: Vector2 = Vector2.ZERO  # sx, sy z broni (Tyrian px/klatkę)
var damage: int = 1                   # attack z broni
var sprite_id: int = 0                # sg z broni

# Parametry homingu i akceleracji
var tx: int = 0                       # homing X (maksymalna korekta na klatkę)
var ty: int = 0                       # homing Y (maksymalna korekta na klatkę)
var acceleration: int = 0             # przyspieszenie Y
var accelerationx: int = 0            # przyspieszenie X
var duration: float = 255.0           # czas życia w klatkach Tyrian (255 = nieskończony)

# Granice usuwania (px Godot)
const BOUNDS_LEFT   = -1400
const BOUNDS_RIGHT  = 1480
const BOUNDS_TOP    = -1000
const BOUNDS_BOTTOM = 1000

# Referencja do węzła wizualnego
@onready var visual: Polygon2D = $Visual

func _ready():
	# Ustaw kolor na podstawie sprite_id (prosta wizualizacja)
	var colors = [
		Color.RED, Color.ORANGE, Color.YELLOW, Color.WHITE,
		Color.PINK, Color.LIGHT_BLUE, Color.LIME, Color.VIOLET
	]
	if visual:
		visual.color = colors[sprite_id % colors.size()]
		
		# Ustaw wymiary pocisku (prosty kwadrat 4x4px Tyrian -> 16x14.4px Godot)
		var width = 4.0 * SCALE_X
		var height = 4.0 * SCALE_Y
		var half_w = width / 2.0
		var half_h = height / 2.0
		visual.polygon = PackedVector2Array([
			Vector2(-half_w, -half_h),
			Vector2(half_w, -half_h),
			Vector2(half_w, half_h),
			Vector2(-half_w, half_h)
		])

func _physics_process(delta):
	# KROK 1: Dodaj akcelerację do velocity (rzadko używane)
	velocity.x += float(accelerationx) * delta * TYRIAN_FPS
	velocity.y += float(acceleration) * delta * TYRIAN_FPS

	# KROK 2: Homing (tylko jeśli tx != 0 lub ty != 0)
	if tx != 0 or ty != 0:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			# Homing X
			if tx != 0:
				if global_position.x > player.global_position.x:
					if velocity.x > -float(tx):
						velocity.x -= 1.0
				else:
					if velocity.x < float(tx):
						velocity.x += 1.0

			# Homing Y
			if ty != 0:
				if global_position.y > player.global_position.y:
					if velocity.y > -float(ty):
						velocity.y -= 1.0
				else:
					if velocity.y < float(ty):
						velocity.y += 1.0

	# Przeliczenie na px/s Godot: tyrian_px_per_frame * scale * TYRIAN_FPS
	var move_x = velocity.x * SCALE_X * TYRIAN_FPS
	var move_y = velocity.y * SCALE_Y * TYRIAN_FPS

	position.x += move_x * delta
	position.y += move_y * delta

	# KROK 3: Sprawdź czy pocisk żyje (duration)
	if duration != 255.0:
		duration -= delta * TYRIAN_FPS
		if duration <= 0.0:
			queue_free()
			return

	# Usuń poza ekranem
	if position.x < BOUNDS_LEFT or position.x > BOUNDS_RIGHT:
		queue_free()
	if position.y < BOUNDS_TOP or position.y > BOUNDS_BOTTOM:
		queue_free()

func _on_body_entered(_body):
	# Kolizja z graczem (lub innym obiektem)
	# TODO: Dodaj logikę zadawania obrażeń graczowi
	queue_free()
