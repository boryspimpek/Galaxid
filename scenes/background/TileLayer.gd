extends Node2D

const TILE_W := 24
const TILE_H := 28

var _tilemap: Array = []
var _textures: Dictionary = {}
var _total_rows: int = 0
var _total_cols: int = 0
var _scroll_y: float = 0.0
var _back_move: int = 1

var _draw_cols: int = 0

func setup(tilemap: Array, textures: Dictionary, cols: int, back_move: int, x_offset: int = 0) -> void:
	_tilemap = tilemap
	_textures = textures
	_total_rows = tilemap.size()
	_total_cols = cols
	_back_move = back_move
	_scroll_y = float((_total_rows - 2) * TILE_H)
	position.x = float(x_offset)
	# ile kolumn potrzeba żeby wypełnić ekran od lewej krawędzi kafelka 0
	_draw_cols = ceili((288.0 - x_offset) / TILE_W)

func set_back_move(value: int) -> void:
	_back_move = value

func _process(_delta: float) -> void:
	if _total_rows == 0:
		return
	_scroll_y -= float(_back_move)
	if _scroll_y < 0.0:
		_scroll_y += float(_total_rows * TILE_H)
	queue_redraw()

func _draw() -> void:
	if _tilemap.is_empty():
		return
	var s := int(_scroll_y)
	var first_row := int(float(s) / TILE_H)
	var offset_y := s % TILE_H

	for i in range(11):
		var sy := i * TILE_H - offset_y
		if sy > 200:
			break
		var row := (first_row + i) % _total_rows
		for col in range(_draw_cols):
			var map_col := col % _total_cols
			var tex: Texture2D = _textures.get(int(_tilemap[row][map_col]))
			if tex != null:
				draw_texture(tex, Vector2(col * TILE_W, sy))
