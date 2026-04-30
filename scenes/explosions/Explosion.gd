extends Node2D

const TYPE_LABELS: Dictionary = {
	0: "hit_flash",
	1: "small_enemy",
	2: "large_ground_tl",
	3: "large_ground_bl",
	4: "large_ground_tr",
	5: "large_ground_br",
	6: "white_smoke",
	7: "large_air_tl",
	8: "large_air_bl",
	9: "large_air_tr",
	10: "large_air_br",
	11: "flash_short",
	12: "medium",
	13: "brief",
}

const TYPE_TTL: Dictionary = {
	0: 7,  1: 12, 2: 12, 3: 12, 4: 12, 5: 12,
	6: 7,  7: 12, 8: 12, 9: 12, 10: 12,
	11: 3, 12: 7, 13: 3,
}

var _textures: Array = []
var _frame: int = 0
var _scroll_y: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func setup(type: int, p_scroll_y: float) -> void:
	_scroll_y = p_scroll_y
	var label: String = TYPE_LABELS.get(type, "type%02d" % type)
	var ttl: int = TYPE_TTL.get(type, 7)
	for f in range(ttl):
		var path := "res://data/explosion_sprites/explo_t%02d_%s_f%02d.png" % [type, label, f]
		if ResourceLoader.exists(path):
			_textures.append(load(path))
	if _textures.is_empty():
		queue_free()
		return
	_sprite.texture = _textures[0]


func _process(_delta: float) -> void:
	position.y += _scroll_y
	_frame += 1
	if _frame >= _textures.size():
		queue_free()
		return
	_sprite.texture = _textures[_frame]
