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

	# --- 4. Usuń poza ekranem ---
	if position.x < BOUNDS_LEFT or position.x > BOUNDS_RIGHT:
		queue_free()
	if position.y < BOUNDS_TOP  or position.y > BOUNDS_BOTTOM:
		queue_free()
