extends Area2D

# --- Parametry pocisku (ustawiane przez WeaponSystem) ---
@export var velocity: Vector2 = Vector2.ZERO
@export var acceleration: Vector2 = Vector2.ZERO  # Przyspieszenie po wystrzeleniu
@export var damage: int = 3
@export var lifetime: float = 0.0  # Czas życia w sekundach (0 = brak limitu)
@export var shot_graphic: int = 0  # ID grafiki (sg z patterns)
# --- Wewnętrzne ---
var lifetime_timer: float = 0.0

func _ready():
	# Warstwa 4 = pocisk gracza; maska 2 = wykrywa wrogów (warstwa 2)
	collision_layer = 4
	collision_mask  = 2
	_apply_shot_graphic()
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)

func _apply_shot_graphic():
	if shot_graphic <= 0:
		return
	var texture = DataManager.get_shot_texture(shot_graphic)
	if texture:
		var sprite = $Sprite2D
		sprite.texture = texture
		sprite.scale = Vector2(4.0, 4.0)

func _physics_process(delta: float):
	velocity += acceleration * delta

	position += Vector2(velocity.x * 4.0, velocity.y * 9.6) * delta

	if lifetime > 0.0:
		lifetime_timer += delta
		if lifetime_timer >= lifetime:
			queue_free()
			return

func _on_area_entered(area: Area2D):
	if area.is_in_group("enemies"):
		area.take_damage(damage)
		queue_free()

func _on_body_entered(_body: Node2D):
	queue_free()
