extends Node2D

const TileLayer = preload("res://scenes/background/TileLayer.gd")
const Starfield = preload("res://scenes/background/Starfield.gd")

var _starfield: Node2D
var _layer1: Node2D
var _layer2: Node2D
var _layer3: Node2D

func setup(level_name: String,
		back_move: int, back_move2: int, back_move3: int,
		map_x: int = 1, map_x2: int = 1, map_x3: int = 1,
		map_y: int = 0) -> void:

	var base_path := _find_level_folder(level_name)
	if base_path.is_empty():
		push_error("TileBackground: brak folderu dla poziomu '%s'" % level_name)
		return

	# Offset X: kolumna (mapX+2) odpowiada x=0 ekranu (tak jak w oryginale)
	var ox1 := -(map_x  + 1) * TileLayer.TILE_W
	var ox2 := -(map_x2 + 1) * TileLayer.TILE_W
	var ox3 := -(map_x3 + 1) * TileLayer.TILE_W

	_starfield = Starfield.new()
	add_child(_starfield)

	_layer1 = _build_layer(base_path + "/layer1", base_path + "/tilemap_layer1.json", 14, back_move,  ox1, map_y)
	_layer2 = _build_layer(base_path + "/layer2", base_path + "/tilemap_layer2.json", 14, back_move2, ox2, map_y)
	_layer3 = _build_layer(base_path + "/layer3", base_path + "/tilemap_layer3.json", 15, back_move3, ox3, map_y)
	add_child(_layer1)
	add_child(_layer2)
	add_child(_layer3)

func set_scroll_speed(back_move: int, back_move2: int, back_move3: int) -> void:
	if _layer1:
		_layer1.set_back_move(back_move)
	if _layer2:
		_layer2.set_back_move(back_move2)
	if _layer3:
		_layer3.set_back_move(back_move3)

# Przesuwa każdą warstwę o dokładną liczbę pikseli obliczoną przez fast_forward_to.
func seek_to(dist1: int, dist2: int, dist3: int) -> void:
	if _layer1: _layer1.seek_to(dist1)
	if _layer2: _layer2.seek_to(dist2)
	if _layer3: _layer3.seek_to(dist3)

func set_starfield_speed(value: int) -> void:
	if _starfield:
		_starfield.set_speed(value)

func set_starfield_active(value: bool) -> void:
	if _starfield:
		_starfield.set_active(value)

# --- helpers ---

func _find_level_folder(level_name: String) -> String:
	var base := "res://data/extracted_map_tiles"
	var dir := DirAccess.open(base)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry.begins_with(level_name + "_"):
			dir.list_dir_end()
			return base + "/" + entry
		entry = dir.get_next()
	dir.list_dir_end()
	return ""

func _build_layer(tiles_path: String, tilemap_path: String, cols: int, back_move: int, x_offset: int, map_y: int = 0) -> Node2D:
	var tilemap := _load_tilemap(tilemap_path)
	var textures := _load_textures(tiles_path)
	var layer := TileLayer.new()
	layer.setup(tilemap, textures, cols, back_move, x_offset, map_y)
	return layer

func _load_tilemap(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("TileBackground: nie można otworzyć " + path)
		return []
	var result = JSON.parse_string(file.get_as_text())
	if result is Array:
		return result
	push_error("TileBackground: JSON nie jest tablicą: " + path)
	return []

func _load_textures(dir_path: String) -> Dictionary:
	var textures := {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("TileBackground: nie można otworzyć katalogu " + dir_path)
		return textures
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		# format: tile_slotNNN_shpMMM.png  ("tile_slot" = 9 znaków, potem 3 cyfry slotu)
		if filename.ends_with(".png") and filename.begins_with("tile_slot"):
			var slot := int(filename.substr(9, 3))
			var tex := _load_png(dir_path + "/" + filename)
			if tex != null:
				textures[slot] = tex
		filename = dir.get_next()
	dir.list_dir_end()
	return textures

func _load_png(path: String) -> ImageTexture:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var img := Image.new()
	if img.load_png_from_buffer(file.get_buffer(file.get_length())) != OK:
		push_error("TileBackground: błąd parsowania PNG: " + path)
		return null
	return ImageTexture.create_from_image(img)
