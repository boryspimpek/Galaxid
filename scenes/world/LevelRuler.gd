@tool
extends Node2D

@export var level_length: int = 10000:
	set(val):
		level_length = val
		queue_redraw()

@export var line_spacing: int = 100:
	set(val):
		line_spacing = val
		queue_redraw()

const SCREEN_W := 360
const SCREEN_H := 200

const COLOR_START := Color(0.04, 0.10, 0.04, 1.0)
const COLOR_A     := Color(0.04, 0.04, 0.14, 1.0)
const COLOR_B     := Color(0.07, 0.07, 0.22, 1.0)
const LINE_COLOR  := Color(0.28, 0.28, 0.52, 0.85)
const LINE_MAJOR  := Color(0.50, 0.50, 0.80, 1.00)
const LABEL_COLOR := Color(0.55, 0.60, 0.95, 1.0)
const FONT_SIZE   := 10

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var font  := ThemeDB.fallback_font
	var steps := level_length / line_spacing

	# Strefa startowa: widoczna od razu (y=0..SCREEN_H w przestrzeni LevelMap)
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), COLOR_START, true)

	# Naprzemienne pasy idące w górę (ujemne Y = późniejsza część poziomu)
	for i in range(steps):
		var y_top := -(i + 1) * line_spacing
		var color := COLOR_A if (i % 2 == 0) else COLOR_B
		draw_rect(Rect2(0, y_top, SCREEN_W, line_spacing), color, true)

	# Linia startowa y=0
	draw_line(Vector2(0, 0), Vector2(SCREEN_W, 0), Color(0.2, 0.8, 0.2, 0.9), 1.5)
	draw_string(font, Vector2(4, -2), "0",
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0.2, 0.8, 0.2, 1.0))

	# Linie i etykiety co line_spacing
	for i in range(1, steps + 1):
		var y       := -i * line_spacing
		var is_major := (i % 10 == 0)
		var col   := LINE_MAJOR if is_major else LINE_COLOR
		var width := 1.5     if is_major else 0.8
		draw_line(Vector2(0, y), Vector2(SCREEN_W, y), col, width)
		draw_string(font, Vector2(4, y - 2), str(i * line_spacing),
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, LABEL_COLOR)

	# Marker końca poziomu
	var y_end := -level_length
	draw_line(Vector2(0, y_end), Vector2(SCREEN_W, y_end), Color(0.9, 0.2, 0.2, 0.9), 1.5)
	draw_string(font, Vector2(4, y_end - 2), "END  %d" % level_length,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0.9, 0.2, 0.2, 1.0))
