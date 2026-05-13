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
var duration: float = 0.0             # czas życia w sekundach (0 = nieskończony)

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

func _physics_process(delta: float):
	# KROK 1: Dodaj akcelerację do velocity (acc już w px/s² z DataManagera)
	velocity.x += float(accelerationx) * delta
	velocity.y += float(acceleration) * delta

	# KROK 2: Homing — 900*delta = 1 Tyrian px/frame per frame, fps-niezależnie
	# float(ty)/2 wynika ze zrównoważenia przeliczenia skali szybkości strzelania
	if (tx != 0 or ty != 0) and is_instance_valid(_player):
		var homing_step := 900 * delta
		if tx != 0:
			velocity.x = move_toward(velocity.x, sign(_player.global_position.x - global_position.x) * float(tx), homing_step)
		if ty != 0:
			velocity.y = move_toward(velocity.y, sign(_player.global_position.y - global_position.y) * float(ty), homing_step)

	position.x += velocity.x * 4.0 * delta
	position.y += velocity.y * 9.6 * delta

	# KROK 3: Sprawdź czy pocisk żyje (duration już w sekundach z DataManagera; 0 = brak limitu)
	if duration > 0.0:
		duration -= delta
		if duration <= 0.0:
			queue_free()
			return


func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		var ds = body.get_node_or_null("DamageSystem")
		if ds:
			ds.take_damage(damage)
	queue_free()
