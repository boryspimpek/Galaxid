extends Node2D

# ---- Stałe przeliczeniowe ----
const TYRIAN_FPS = 15.0
const SCALE_X    = 1280.0 / 320.0   # = 4.0
const SCALE_Y    = 720.0  / 200.0   # = 3.6

# ---- Statystyki ----
@export var armor: int = 1
@export var esize: int = 0
@export var enemy_id: int = 0
@export var event_type: int = 0
@export var link_num: int = 0
@export var enemy_slot: int = 0

# ---- Ruch (surowe jednostki Tyrian: px/klatkę @ 30 FPS) ----
# velocity odpowiada exc/eyc z silnika Tyrian
@export var velocity: Vector2 = Vector2(0, 0)
@export var fixed_move_y: int = 0
# Prędkość scrollingu właściwa dla slotu tego wroga (px/klatkę Tyrian)
@export var scroll_y: int = 2

# ---- Silnik wahadłowy (xcaccel / ycaccel) ----
@export var excc: int = 0
@export var eycc: int = 0
@export var xrev: int = 0
@export var yrev: int = 0

var exccw: int = 0
var eyccw: int = 0
var exccwmax: int = 0
var eyccwmax: int = 0
var exccadd: int = 1
var eyccadd: int = 1

# ---- Losowe przyspieszenie ----
@export var xaccel: int = 0
@export var yaccel: int = 0

# ---- System strzelania ----
@export var tur: Array = [0, 0, 0]  # ID broni [down, right, left]
@export var freq: Array = [0, 0, 0]  # Częstotliwość strzelania [down, right, left]
var weapons_data: Array = []  # Dane broni z LevelManager
var projectile_scene: PackedScene  # Scena pocisku wroga

# Runtime zmienne strzelania
var eshotwait: Array = [0, 0, 0]  # Licznik cooldown dla każdego kierunku
var eshotwaitmax: Array = [0, 0, 0]  # Maksymalny cooldown z freq


# ---- Granice usuwania (px Godot) ----
const BOUNDS_LEFT   = -1400
const BOUNDS_RIGHT  = 1480
const BOUNDS_TOP    = -1000
const BOUNDS_BOTTOM = 1000

# Referencje do węzłów
@onready var visual: Polygon2D = $Visual
@onready var debug_label: Label = $DebugLabel

func _ready():
	# Inicjalizacja silnika wahadłowego X
	if excc != 0:
		exccw    = abs(excc)
		exccwmax = exccw
		exccadd  = 1 if excc > 0 else -1
		if xrev == 0:
			xrev = 100

	# Inicjalizacja silnika wahadłowego Y
	if eycc != 0:
		eyccw    = abs(eycc)
		eyccwmax = eyccw
		eyccadd  = 1 if eycc > 0 else -1
		if yrev == 0:
			yrev = 100

	# Inicjalizacja systemu strzelania
	for i in range(3):
		var weapon_id = tur[i]
		if weapon_id == 252:
			eshotwait[i] = 1
		elif weapon_id != 0:
			eshotwait[i] = 20
		else:
			eshotwait[i] = 255
		eshotwaitmax[i] = freq[i]

	# Ustaw kolor na podstawie enemy_id
	var colors = [
		Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW,
		Color.CYAN, Color.MAGENTA, Color.ORANGE, Color.PURPLE
	]
	if visual:
		visual.color = colors[enemy_id % colors.size()]
		
		# Ustaw wymiary kwadratu na podstawie esize
		# esize 0: 14x12px Tyrian -> 56x43.2px Godot
		# esize 1: 24x28px Tyrian -> 96x100.8px Godot
		var width: float
		var height: float
		if esize == 0:
			width = 14.0 * SCALE_X
			height = 12.0 * SCALE_Y
		else:
			width = 24.0 * SCALE_X
			height = 28.0 * SCALE_Y
		
		# Utwórz prostokąt wyśrodkowany w (0,0)
		var half_w = width / 2.0
		var half_h = height / 2.0
		visual.polygon = PackedVector2Array([
			Vector2(-half_w, -half_h),
			Vector2(half_w, -half_h),
			Vector2(half_w, half_h),
			Vector2(-half_w, half_h)
		])
	
	if debug_label:
		debug_label.text = "ID:%d\nET:%d" % [enemy_id, event_type]

func _process_shooting(_delta):
	# Przetwarzaj każdy kierunek strzelania
	for i in range(3):
		if tur[i] == 0 or freq[i] == 0:
			continue  # Brak broni w tym kierunku

		eshotwait[i] -= 1
		if eshotwait[i] <= 0:
			_fire_projectile(i)
			eshotwait[i] = eshotwaitmax[i]

func _fire_projectile(direction_index: int):
	if not projectile_scene or weapons_data.is_empty():
		print("ERROR: projectile_scene lub weapons_data puste")
		return

	var weapon_id = int(tur[direction_index])
	var weapon_index_str = str(weapon_id).pad_zeros(4)
	print("Strzał! weapon_id=", weapon_id, " direction=", direction_index)
	
	# Znajdź broń w weapons_data po indeksie
	var weapon_data = null
	for weapon in weapons_data:
		if weapon.get("index") == weapon_index_str:
			weapon_data = weapon
			break
	
	if not weapon_data:
		print("ERROR: Nie znaleziono broni o ID=", weapon_id)
		return

	var patterns = weapon_data.get("patterns", [])
	if patterns.is_empty():
		return

	var pattern = patterns[0]  # Użyj pierwszego patternu
	var attack = pattern.get("attack", 1)
	var sx = pattern.get("sx", 0)
	var sy = pattern.get("sy", 0)
	var bx = pattern.get("bx", 0)
	var by = pattern.get("by", 0)
	var sg = pattern.get("sg", 0)

	# Oblicz prędkość w zależności od kierunku
	var projectile_velocity = Vector2(float(sx), float(sy))
	match direction_index:
		0:  # down
			projectile_velocity = Vector2(float(sx), float(sy))
		1:  # right
			projectile_velocity = Vector2(float(abs(sx)), float(sy))
		2:  # left
			projectile_velocity = Vector2(float(-abs(sx)), float(sy))

	# Utwórz pocisk
	var projectile = projectile_scene.instantiate()
	projectile.velocity = projectile_velocity
	projectile.damage = attack
	projectile.sprite_id = sg

	# Oblicz pozycję startową z offsetem bx/by
	var offset_x = float(bx) * SCALE_X
	var offset_y = float(by) * SCALE_Y
	projectile.global_position = global_position + Vector2(offset_x, offset_y)

	# Dodaj do sceny (jako dziecko LevelManager, nie wroga)
	get_parent().add_child(projectile)
	print("Pocisk utworzony na pozycji: ", projectile.global_position, " velocity: ", projectile.velocity)

func _process(delta):
	# Kolejność zgodna z JE_drawEnemy w Tyrianie:
	# 1. fixed_move_y
	# 2. velocity (eyc) — po ewentualnej aktualizacji silnika wahadłowego
	# 3. scroll tła (tempBackMove)

	# --- NOWOŚĆ: Stałe przyspieszenie liniowe (xaccel/yaccel) ---
	# W Tyrianie te wartości są stosowane co klatkę (15 FPS).
	# Musimy je przemnożyć przez delta i TYRIAN_FPS, aby działały płynnie.
	velocity.x += float(xaccel) * TYRIAN_FPS * delta
	velocity.y += float(yaccel) * TYRIAN_FPS * delta

	# --- 1. Silnik wahadłowy X ---
	if excc != 0:
		exccw -= 1
		if exccw <= 0:
			velocity.x += exccadd
			exccw = exccwmax
			if velocity.x == xrev:
				excc    = -excc
				xrev   = -xrev
				exccadd = -exccadd

	# --- 2. Silnik wahadłowy Y ---
	if eycc != 0:
		eyccw -= 1
		if eyccw <= 0:
			velocity.y += eyccadd
			eyccw = eyccwmax
			if velocity.y == yrev:
				eycc    = -eycc
				yrev   = -yrev
				eyccadd = -eyccadd

	# --- 3. Przeliczenie na px/s Godot i zastosowanie ruchu ---
	# Każdy składnik (fixed, velocity, scroll) jest w px/klatkę Tyrian.
	# Przeliczamy: tyrian_px_per_frame * scale * TYRIAN_FPS = godot_px_per_s
	var move_x = (velocity.x)                          * SCALE_X * TYRIAN_FPS
	var move_y = (float(fixed_move_y) + velocity.y + float(scroll_y)) * SCALE_Y * TYRIAN_FPS

	position.x += move_x * delta
	position.y += move_y * delta

	# --- 4. System strzelania ---
	_process_shooting(delta)

	# --- 5. Usuń poza ekranem ---
	if position.x < BOUNDS_LEFT or position.x > BOUNDS_RIGHT:
		queue_free()
	if position.y < BOUNDS_TOP  or position.y > BOUNDS_BOTTOM:
		queue_free()
