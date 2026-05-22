extends Area2D

# ============================================================================
# ENEMY — baza wszystkich wrogów.
# Właściwości eksportowane są nadpisywane w scenach Enemy_NNN.tscn.
# ============================================================================

#region Sygnały
signal projectile_spawned(projectile)
#endregion

#region Właściwości eksportowane (nadpisywane per-scena w Enemy_NNN.tscn)

# -- Statystyki --
@export var armor: int = 1
@export var esize: int = 0
@export var value: int = 0

# -- Ruch bazowy (px/klatkę Tyrian) --
@export var xmove: int = 0
@export var ymove: int = 0

# -- System strzelania --
@export var tur: Array  = [0, 0, 0]   # ID broni [down, right, left]
@export var freq: Array = [0, 0, 0]   # Częstotliwość strzałów [down, right, left]

#endregion

#region Stan wewnętrzny

var velocity: Vector2 = Vector2.ZERO
var projectile_scene: PackedScene

var eshotwait:     Array = [0.0, 0.0, 0.0]
var eshotwaitmax:  Array = [0.0, 0.0, 0.0]
var eshotmultipos: Array = [0, 0, 0]

var _player: Node2D
var _weapon_cache: Array = [null, null, null]

#endregion

# ============================================================================
# INICJALIZACJA
# ============================================================================

func _ready():
	add_to_group("enemies")
	collision_layer = 2
	collision_mask  = 5
	body_entered.connect(_on_body_entered)

	velocity = Vector2(float(xmove), float(ymove))
	projectile_scene = GameConstants.enemy_projectile_scene

	_init_shooting_timers()

	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)
	$VisibleOnScreenNotifier2D.screen_entered.connect(_on_screen_entered)
	_player = get_tree().get_first_node_in_group("player")
	refresh_weapon_cache()
	set_process(false)

func _init_shooting_timers():
	for i in range(3):
		eshotwaitmax[i] = freq[i]
		eshotwait[i] = freq[i]

func _on_screen_entered():
	set_process(true)
	if get_parent() is PathFollow2D and get_parent().has_method("activate"):
		get_parent().activate()

func _on_screen_exited():
	if get_parent() is PathFollow2D:
		if get_parent().remove_at_end:
			return
	queue_free()

func refresh_weapon_cache():
	for i in range(3):
		_weapon_cache[i] = DataManager.get_weapon_by_id(tur[i]) if tur[i] != 0 else {}

# ============================================================================
# PĘTLA GŁÓWNA
# ============================================================================

func _process(delta: float):
	if not (get_parent() is PathFollow2D):
		position += velocity * delta
	_process_shooting(delta)

# ============================================================================
# SYSTEM STRZELANIA
# ============================================================================

func _process_shooting(delta: float):
	for i in range(3):
		if tur[i] == 0 or freq[i] == 0:
			continue
		eshotwait[i] -= delta
		if eshotwait[i] <= 0.0:
			_fire_projectile(i)
			eshotwait[i] += eshotwaitmax[i]

func _fire_projectile(direction_index: int):
	if not projectile_scene:
		push_error("Enemy: projectile_scene pusty")
		return

	var weapon_data: Dictionary = _weapon_cache[direction_index] if _weapon_cache[direction_index] != null else {}
	if weapon_data.is_empty():
		push_error("Enemy: nie znaleziono broni o ID=%d" % int(tur[direction_index]))
		return

	var patterns = weapon_data.get("patterns", [])
	if patterns.is_empty():
		return

	var weapon_multi = int(weapon_data.get("multi", 1))
	var weapon_max   = int(weapon_data.get("max", 1))
	var aim          = int(weapon_data.get("aim", 0))

	for _i in range(weapon_multi):
		var temp_pos = eshotmultipos[direction_index]
		if temp_pos >= patterns.size():
			temp_pos = 0

		var pattern = patterns[temp_pos]
		var projectile_velocity: Vector2
		if aim > 0:
			projectile_velocity = _calc_aim_velocity(aim, pattern.get("sx", 0), pattern.get("sy", 0))
		else:
			projectile_velocity = _calc_dir_velocity(direction_index, pattern.get("sx", 0), pattern.get("sy", 0))

		var projectile = projectile_scene.instantiate()
		projectile.velocity      = projectile_velocity
		projectile.damage        = pattern.get("attack", 1)
		projectile.sprite_id     = pattern.get("sg", 0)
		projectile.tx            = int(weapon_data.get("tx", 0))
		projectile.ty            = int(weapon_data.get("ty", 0))
		projectile.acceleration  = int(weapon_data.get("acceleration", 0))
		projectile.accelerationx = int(weapon_data.get("accelerationx", 0))
		projectile.duration      = float(pattern.get("del", 0.0))
		projectile.global_position = global_position + Vector2(float(pattern.get("bx", 0)), float(pattern.get("by", 0)))

		projectile_spawned.emit(projectile)
		eshotmultipos[direction_index] = (eshotmultipos[direction_index] + 1) % weapon_max

func _calc_aim_velocity(aim: int, sx: int, sy: int) -> Vector2:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(_player):
		return Vector2(float(sx), float(sy))
	var dir = global_position.direction_to(_player.global_position)
	if dir == Vector2.ZERO:
		return Vector2(float(sx), float(sy))
	return dir * float(aim)

func _calc_dir_velocity(direction_index: int, sx: int, sy: int) -> Vector2:
	match direction_index:
		1: return Vector2(float(sy),  float(-sx))   # right
		2: return Vector2(float(-sy), float(-sx))   # left
		_: return Vector2(float(sx),  float(sy))    # down

# ============================================================================
# SYSTEM OBRAŻEŃ I ŚMIERCI
# ============================================================================

func take_damage(amount: int):
	armor -= amount
	if armor <= 0:
		die()
	else:
		SoundManager.play_sound(3)
		_flash_hit()

func _flash_hit():
	modulate = Color(50, 50, 50, 1)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.06)

func die():
	var parent := _get_level_parent()
	if parent:
		var explosion: Node2D = GameConstants.explosion_scene.instantiate()
		explosion.position = (parent as Node2D).to_local(global_position)
		parent.add_child(explosion)
	SoundManager.play_sound(9 if esize == 1 else 8)
	queue_free()

func _get_level_parent() -> Node:
	var p = get_parent()
	while p and (p is PathFollow2D or p is Path2D):
		p = p.get_parent()
	return p

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		var ds = body.get_node_or_null("DamageSystem")
		if ds:
			ds.take_damage(armor)
		die()
