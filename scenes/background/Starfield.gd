extends Node2D

# Implementacja pola gwiezdnego identyczna z backgrnd.c: update_and_draw_starfield()
# 100 gwiazd scrolluje w dół; każda ma własną prędkość (2-4) + globalny modyfikator.
# Pozycja to uint16 — naturalne overflow przerzuca gwiazdę z dołu na górę.

const SCREEN_W := 288
const SCREEN_H := 200
const MAX_STARS := 100
const STARFIELD_HUE := 144  # 0x90 — dolna granica zakresu kolorów w palecie

var _stars: Array = []
var _speed: int = 1   # starfield_speed z Tyriana (event type 1)
var _active: bool = true

func _ready() -> void:
	_init_stars()

func _init_stars() -> void:
	_stars.clear()
	for i in range(MAX_STARS):
		_stars.append({
			"position": randi() % SCREEN_W + randi() % SCREEN_H * SCREEN_W,
			"speed":    randi() % 3 + 2,   # 2..4
			"color_idx": randi() % 16       # 0..15 względem STARFIELD_HUE
		})

func set_speed(value: int) -> void:
	_speed = value

func set_active(value: bool) -> void:
	_active = value
	queue_redraw()

func _process(_delta: float) -> void:
	if not _active:
		return
	for star in _stars:
		# Przesuń o (speed + global_speed) wierszy w dół; & 0xFFFF = overflow jak uint16
		star.position = (star.position + (star.speed + _speed) * SCREEN_W) & 0xFFFF
	queue_redraw()

func _draw() -> void:
	if not _active:
		return
	for star in _stars:
		var x: int = star.position % SCREEN_W
		var y: int = star.position / SCREEN_W

		# Rysuj tylko w widocznym obszarze (z marginesem 2px na cross-halo)
		if y < 2 or y >= SCREEN_H - 2:
			continue

		var t: float = star.color_idx / 15.0
		var center_col := Color(0.45 + 0.55 * t, 0.45 + 0.55 * t, 0.55 + 0.45 * t)

		draw_rect(Rect2(x, y, 1, 1), center_col)

		# Cross-halo dla jaśniejszych gwiazd (color_idx >= 4, jak w oryginale color >= HUE+4)
		if star.color_idx >= 4:
			var halo_col := Color(center_col.r * 0.6, center_col.g * 0.6, center_col.b * 0.6)
			draw_rect(Rect2(x + 1, y,     1, 1), halo_col)
			draw_rect(Rect2(x - 1, y,     1, 1), halo_col)
			draw_rect(Rect2(x,     y + 1, 1, 1), halo_col)
			draw_rect(Rect2(x,     y - 1, 1, 1), halo_col)
