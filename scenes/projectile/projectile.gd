extends Area2D

# --- Parametry pocisku (ustawiane przez WeaponSystem) ---
@export var velocity: Vector2 = Vector2.ZERO
@export var acceleration: Vector2 = Vector2.ZERO  # Przyspieszenie po wystrzeleniu
@export var damage: int = 3
@export var lifetime: float = 0.0  # Czas życia w sekundach (0 = brak limitu)
@export var shot_graphic: int = 0  # ID grafiki (sg z patterns)
@export var circlesize: int = 0  # Rozmiar okręgu (circleSize z weapon)

# --- Circlesize (ruch okrężny) ---
var circle_dev_x: int = 0  # Aktualne odchylenie X od środka
var circle_dev_y: int = 0  # Aktualne odchylenie Y od środka
var circle_dir_x: int = 0  # Kierunek zmiany odchylenia X (+1 lub -1)
var circle_dir_y: int = 0  # Kierunek zmiany odchylenia Y (+1 lub -1)
var circle_size_x: int = 0  # Promień orbity w osi X
var circle_size_y: int = 0  # Promień orbity w osi Y
var circle_center: Vector2 = Vector2.ZERO  # Środek orbity (pozycja startowa)

# --- Wewnętrzne ---
var lifetime_timer: float = 0.0
const _CIRCLE_STEP: float = 1.0 / 30.0  # circlesize taktuje z prędkością Tyriana (30fps)
var _circle_timer: float = 0.0

func _ready():
	# Warstwa 4 = pocisk gracza; maska 2 = wykrywa wrogów (warstwa 2)
	collision_layer = 4
	collision_mask  = 2
	_init_circlesize()
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

func _init_circlesize():
	# Inicjalizacja ruchu okrężnego zgodnie z dokumentacją Tyriana
	if circlesize == 0:
		# Normalny pocisk - leci prosto
		circle_dev_x = 0
		circle_dir_x = 0
		circle_dev_y = 0
		circle_dir_y = 0
		circle_size_x = 0
		circle_size_y = 0
	else:
		# Pocisk okrężny
		if circlesize > 19:
			# Kodowanie elipsy: (Y*20 + X)
			var circsize_mod20 = circlesize % 20
			circle_size_x = circsize_mod20
			circle_dev_x = circsize_mod20 >> 1  # dzielenie całkowite przez 2
			
			var circsize_div20 = floori(circlesize / 20.0)
			circle_size_y = circsize_div20
			circle_dev_y = circsize_div20 >> 1
		else:
			# Dla wartości 1-19: okrąg (romb) o jednakowych promieniach
			circle_size_x = circlesize
			circle_size_y = circlesize
			circle_dev_x = circlesize >> 1
			circle_dev_y = circlesize >> 1
		
		# Początkowy kierunek ruchu: w prawo (+1) i w górę (-1)
		circle_dir_x = 1
		circle_dir_y = -1
	
	# Zapamiętaj środek orbity (pozycja startowa)
	circle_center = position

func _physics_process(delta: float):
	# Krok 2: Przyspieszenie → prędkość (acc już w px/s² z DataManagera)
	velocity += acceleration * delta

	# Krok 3: Prędkość → pozycja
	position += Vector2(velocity.x * 4.0, velocity.y * 9.6) * delta

	# Krok 5: Ruch okrężny (circlesize) - aktualizowany co ~1/30s żeby zachować oryginalną prędkość
	if circlesize > 0:
		_circle_timer += delta
		while _circle_timer >= _CIRCLE_STEP:
			_circle_timer -= _CIRCLE_STEP
			circle_dev_x += circle_dir_x
			if abs(circle_dev_x) == circle_size_x:
				circle_dir_x = -circle_dir_x
			circle_dev_y += circle_dir_y
			if abs(circle_dev_y) == circle_size_y:
				circle_dir_y = -circle_dir_y
		position += Vector2(float(circle_dev_x), float(circle_dev_y))

	# Obsługa czasu życia (lifetime już w sekundach z DataManagera; 0 = brak limitu)
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
