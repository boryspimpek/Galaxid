extends Area2D

# Parametry pocisku
var velocity: Vector2 = Vector2.ZERO  # sx, sy z broni (Tyrian px/klatkę)
var damage: int = 1                   # attack z broni
var sprite_id: int = 0                # sg z broni
var anim_max: int = 0                 # weapAni z broni (0 = brak animacji)

# Parametry homingu i akceleracji
var tx: int = 0                       # homing X (maksymalna korekta na klatkę)
var ty: int = 0                       # homing Y (maksymalna korekta na klatkę)
var acceleration: int = 0             # przyspieszenie Y
var accelerationx: int = 0            # przyspieszenie X
var duration: float = 255.0           # czas życia w klatkach Tyrian (255 = nieskończony)

# Granice usuwania (z GameConstants)
const BOUNDS_LEFT   = GameConstants.BOUNDS_LEFT
const BOUNDS_RIGHT  = GameConstants.BOUNDS_RIGHT
const BOUNDS_TOP    = GameConstants.BOUNDS_TOP
const BOUNDS_BOTTOM = GameConstants.BOUNDS_BOTTOM

# Referencja do węzła wizualnego
@onready var visual: Sprite2D = $Visual

var _anim_frames: Array = []
var _anim_frame: int = 0

func _ready():
	# Warstwa 8 = pocisk wroga; maska 1 = wykrywa gracza (warstwa 1)
	collision_layer = 8
	collision_mask  = 1
	body_entered.connect(_on_body_entered)
	_apply_shot_graphic()

func _apply_shot_graphic():
	if sprite_id <= 0 or not visual:
		return
	_anim_frames = DataManager.get_shot_texture_frames(sprite_id, anim_max)
	if _anim_frames.size() > 0:
		visual.texture = _anim_frames[0]

func _physics_process(_delta):
	# Animacja klatek (zgodnie z Tyrianem: +1 każda klatka, reset do 0)
	if _anim_frames.size() > 1:
		_anim_frame = (_anim_frame + 1) % _anim_frames.size()
		visual.texture = _anim_frames[_anim_frame]

	# KROK 1: Dodaj akcelerację do velocity (rzadko używane)
	velocity.x += float(accelerationx)
	velocity.y += float(acceleration)

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

	var move_x = velocity.x
	var move_y = velocity.y

	position.x += move_x	
	position.y += move_y	

	# KROK 3: Sprawdź czy pocisk żyje (duration)
	if duration != 255.0:
		duration -= 1
		if duration <= 0.0:
			queue_free()
			return

	# Usuń poza ekranem
	if position.x < BOUNDS_LEFT or position.x > BOUNDS_RIGHT:
		queue_free()
	if position.y < BOUNDS_TOP or position.y > BOUNDS_BOTTOM:
		queue_free()

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		var ds = body.get_node_or_null("DamageSystem")
		if ds:
			ds.take_damage(damage)
	queue_free()
