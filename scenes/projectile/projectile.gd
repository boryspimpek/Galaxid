extends Area2D

const TYRIAN_FPS = GameConstants.TYRIAN_FPS

# --- Parametry pocisku (ustawiane przez WeaponSystem) ---
@export var velocity: Vector2 = Vector2.ZERO
@export var acceleration: Vector2 = Vector2.ZERO  # Przyspieszenie po wystrzeleniu
@export var damage: int = 3
@export var lifetime: int = 0  # Czas życia (del z patterns)
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

func _ready():
	# Warstwa 4 = pocisk gracza; maska 2 = wykrywa wrogów (warstwa 2)
	collision_layer = 4
	collision_mask  = 2
	_init_circlesize()

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

func _physics_process(delta):
	# Krok 2: Przyspieszenie → prędkość
	velocity += acceleration * delta * TYRIAN_FPS
	
	# Krok 3: Prędkość → pozycja
	var move_x = velocity.x * TYRIAN_FPS
	var move_y = velocity.y * TYRIAN_FPS
	position += Vector2(move_x, move_y) * delta
	
	# Krok 5: Ruch okrężny (circlesize) - DODAWANE PO normalnym ruchu
	if circlesize > 0:
		# Oś X
		circle_dev_x += circle_dir_x
		position.x += circle_dev_x
		if abs(circle_dev_x) == circle_size_x:
			circle_dir_x = -circle_dir_x
		
		# Oś Y
		circle_dev_y += circle_dir_y
		position.y += circle_dev_y
		if abs(circle_dev_y) == circle_size_y:
			circle_dir_y = -circle_dir_y
	
	# Obsługa czasu życia (jeśli lifetime > 0)
	if lifetime > 0:
		lifetime_timer += delta
		if lifetime_timer >= lifetime:
			queue_free()
			return
	
	# Usuwamy pocisk gdy wyjdzie poza viewport
	var vp = get_viewport_rect().size
	if position.y < -10 or position.y > vp.y + 10 or position.x < -10 or position.x > vp.x + 10:
		queue_free()

func _on_area_entered(area: Area2D):
	if area.is_in_group("enemies"):
		area.take_damage(damage)
		queue_free()

func _on_body_entered(_body: Node2D):
	queue_free()
