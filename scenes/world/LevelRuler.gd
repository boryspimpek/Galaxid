@tool
extends Node2D

## Wizualna linijka poziomu — widoczna w edytorze Godota (@tool).
## Pokazuje znaczniki czasowe w przestrzeni LevelMap.
## scroll_speed musi zgadzać się z wartością w LevelManager (px/s, delta-time).
## Wrogowie na Y=-N pojawiają się po N/scroll_speed sekundach od startu.

@export var scroll_speed: int = 20            ## musi być równy scroll_speed w LevelManager
@export var level_length_seconds: int = 180   ## całkowita długość poziomu w sekundach
@export var show_in_game: bool = false         ## czy linijka widoczna w trakcie gry

const LEVEL_W   := 1080
const LEVEL_H   := 1920
const FONT_SIZE := 24

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint() and not show_in_game:
		return

	var px_per_sec: float = float(scroll_speed)
	var total_px: float   = level_length_seconds * px_per_sec

	_draw_background(total_px)
	_draw_start_zone()
	_draw_time_markers(px_per_sec, total_px)
	_draw_borders(total_px)

# ── Tło całego poziomu ──────────────────────────────────────────────────────
func _draw_background(total_px: float) -> void:
	draw_rect(Rect2(0, -total_px, LEVEL_W, total_px + 800),
			  Color(0.03, 0.03, 0.18, 0.35), true)

# ── Zielona strefa "widoczna od startu" (Y 0..200 = pierwszy ekran) ─────────
func _draw_start_zone() -> void:
	draw_rect(Rect2(0, 0, LEVEL_W, LEVEL_H), Color(0.2, 0.9, 0.2, 0.12), true)
	draw_rect(Rect2(0, 0, LEVEL_W, LEVEL_H), Color(0.2, 0.9, 0.2, 0.5), false, 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(4, 12), "START (widoczne od razu)",
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0.2, 0.9, 0.2, 0.9))

# ── Poziome kreski co 1s, pogrubione co 5s, etykiety co 10s ────────────────
func _draw_time_markers(px_per_sec: float, total_px: float) -> void:
	var font := ThemeDB.fallback_font
	var y   := px_per_sec          # zacznij od 1s (Y=0 to strefa start)
	var sec := 1

	while y <= total_px:
		var screen_y := -y
		var is_10s := (sec % 10 == 0)
		var is_5s  := (sec %  5 == 0)

		var col: Color
		var thickness: float
		if is_10s:
			col       = Color(1.0, 0.85, 0.1, 0.9)
			thickness = 1.5
		elif is_5s:
			col       = Color(0.8, 0.55, 0.15, 0.7)
			thickness = 1.0
		else:
			col       = Color(0.45, 0.45, 0.45, 0.35)
			thickness = 0.5

		draw_line(Vector2(0, screen_y), Vector2(LEVEL_W, screen_y), col, thickness)

		if is_10s or is_5s:
			draw_string(font, Vector2(4, screen_y - 2),
						"%ds  (Y=-%d)" % [sec, int(y)],
						HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, col)

		y   += px_per_sec
		sec += 1

# ── Ramka poziomu + etykiety KONIEC ─────────────────────────────────────────
func _draw_borders(total_px: float) -> void:
	var font := ThemeDB.fallback_font

	# Lewa i prawa krawędź
	draw_line(Vector2(0,       -total_px), Vector2(0,       800), Color(0.4, 0.4, 0.9, 0.4), 1.0)
	draw_line(Vector2(LEVEL_W, -total_px), Vector2(LEVEL_W, 800), Color(0.4, 0.4, 0.9, 0.4), 1.0)

	# Dolna krawędź startu (Y=200)
	draw_line(Vector2(0, LEVEL_H), Vector2(LEVEL_W, LEVEL_H), Color(0.2, 0.9, 0.2, 0.7), 1.5)

	# Górna krawędź końca poziomu
	draw_line(Vector2(0, -total_px), Vector2(LEVEL_W, -total_px),
			  Color(1.0, 0.25, 0.25, 0.9), 1.5)
	draw_string(font, Vector2(4, -total_px - 4),
				"KONIEC POZIOMU  (%ds / Y=-%d)" % [level_length_seconds, int(total_px)],
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1.0, 0.25, 0.25, 1.0))
