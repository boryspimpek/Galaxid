extends Area2D

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

var _player: Node2D  # Cache — ustawiany raz w _ready(), nie szukamy w drzewie co klatka

# Referencja do węzła wizualnego
@onready var visual: Sprite2D = $Visual

func _ready():
	# Warstwa 8 = pocisk wroga; maska 1 = wykrywa gracza (warstwa 1)
	collision_layer = 8
	collision_mask  = 1
	body_entered.connect(_on_body_entered)
	_apply_shot_graphic()
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	_player = get_tree().get_first_node_in_group("player")

func _apply_shot_graphic():
	if sprite_id <= 0 or not visual:
		return
	var texture = DataManager.get_shot_texture(sprite_id)
	if texture:
		visual.texture = texture

func _physics_process(_delta):
	# KROK 1: Dodaj akcelerację do velocity (rzadko używane)
	velocity.x += float(accelerationx)
	velocity.y += float(acceleration)

	# KROK 2: Homing (tylko jeśli tx != 0 lub ty != 0)
	if (tx != 0 or ty != 0) and is_instance_valid(_player):
		if tx != 0:
			velocity.x = move_toward(velocity.x, sign(_player.global_position.x - global_position.x) * float(tx), 1.0)
		if ty != 0:
			velocity.y = move_toward(velocity.y, sign(_player.global_position.y - global_position.y) * float(ty), 1.0)

	position += velocity * 4

	# KROK 3: Sprawdź czy pocisk żyje (duration)
	if duration != 255.0:
		duration -= 1
		if duration <= 0.0:
			queue_free()
			return


func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		var ds = body.get_node_or_null("DamageSystem")
		if ds:
			ds.take_damage(damage)
	queue_free()
