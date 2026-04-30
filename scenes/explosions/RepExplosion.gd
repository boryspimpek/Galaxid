extends Node2D

# Powtarzająca eksplozja — odpowiednik rep_explosions[] z Tyrian.
# Odpala 'bursts_left' serii eksplozji co kilka klatek, z losowym jitterem.
# Po zakończeniu zwalnia się automatycznie.

var _bursts_left: int = 0
var _big: bool = false
var _scroll_y: float = 0.0
var _ticks_since_last: int = 0
var _next_delay: int = 3

# Offsets i typy dla czterech rogów dużej eksplozji powietrznej
const LARGE_OFFSETS := [Vector2(-6, -14), Vector2(6, -14), Vector2(-6, 0), Vector2(6, 0)]
const LARGE_TYPES   := [7, 9, 8, 10]


func setup(bursts: int, big: bool, p_scroll_y: float) -> void:
	_bursts_left = bursts
	_big = big
	_scroll_y = p_scroll_y
	_next_delay = 4 if big else 3


func _process(_delta: float) -> void:
	if _bursts_left <= 0:
		queue_free()
		return

	# Pozycja centrum dryfuje z scrollem (backMove2 ≈ scroll_y, +1 dodatkowy)
	position.y += _scroll_y + 1.0

	_ticks_since_last += 1
	if _ticks_since_last < _next_delay:
		return

	_ticks_since_last = 0
	_next_delay = (4 + randi() % 3) if _big else 3

	_fire_burst()
	_bursts_left -= 1


func _fire_burst() -> void:
	var parent := get_parent()
	if not parent:
		return

	var jitter := Vector2(
		float(randi() % 24) - 12.0,
		float(randi() % 27) - 24.0)
	var burst_pos: Vector2 = global_position + jitter

	if _big:
		for i in range(4):
			_spawn_explosion(parent, burst_pos + LARGE_OFFSETS[i], LARGE_TYPES[i])
		SoundManager.play_sound(9)
	else:
		_spawn_explosion(parent, burst_pos, 1)
		SoundManager.play_sound(9)


func _spawn_explosion(parent: Node, pos: Vector2, type: int) -> void:
	var explosion: Node2D = GameConstants.explosion_scene.instantiate()
	explosion.global_position = pos
	parent.add_child(explosion)
	explosion.setup(type, _scroll_y)
