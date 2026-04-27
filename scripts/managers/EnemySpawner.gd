extends Node

# Klasa odpowiedzialna za tworzenie wrogów i random spawn

var level_manager: Node2D
var _scene_cache: Dictionary = {}  # enemy_id_str -> PackedScene | null

# Dane scrollingu i mapy
var back_move: int = 1
var back_move3: int = 3
var map_x3: int = 1
var background3x1: bool = false
var background3x1b: bool = false
var small_enemy_adjust: bool = false

# Random spawn system
var enemies_active: bool = false
var level_enemy_frequency: int = 96
var level_enemies: Array = []

func _init(p_level_manager: Node2D):
	level_manager = p_level_manager

func set_scroll_data(p_back_move: int, p_back_move3: int, p_map_x3: int):
	back_move = p_back_move
	back_move3 = p_back_move3
	map_x3 = p_map_x3

func set_background_flags(p_background3x1: bool, p_background3x1b: bool):
	background3x1 = p_background3x1
	background3x1b = p_background3x1b

func set_small_enemy_adjust(active: bool):
	small_enemy_adjust = active

func set_random_spawn_data(p_level_enemies: Array, p_level_enemy_frequency: int = 96):
	level_enemies = p_level_enemies
	level_enemy_frequency = p_level_enemy_frequency

func set_enemies_active(p_active: bool):
	enemies_active = p_active

func process_random_spawn(_delta: float):
	if not enemies_active or level_enemies.is_empty():
		return

	if randi() % 100 > level_enemy_frequency:
		var enemy_id = level_enemies[randi() % level_enemies.size()]
		var enemy = _instantiate(enemy_id)
		if not enemy:
			return

		var spawn_x = enemy.startx
		if enemy.startxc != 0:
			spawn_x = enemy.startx + (randi() % (enemy.startxc * 2)) - enemy.startxc + 1

		var spawn_pos = Vector2(float(spawn_x), float(enemy.starty))

		_setup_enemy(enemy, enemy_id, spawn_pos,
			Vector2(float(enemy.xmove), float(enemy.ymove)),
			0, back_move, 0, 0, 25)

		enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
		level_manager.add_child(enemy)

func spawn_enemy(event: Dictionary):
	var enemy_id = int(event.get("enemy_id", 0))
	var enemy = _instantiate(enemy_id)
	if not enemy:
		return

	var spawn_pos = Vector2(float(event.get("screen_x", 0)), float(event.get("screen_y", 0)))
	if small_enemy_adjust and enemy.esize == 0:
		spawn_pos.x -= 10
		spawn_pos.y -= 7

	var enemy_slot = int(event.get("enemy_slot", 25))
	_setup_enemy(enemy, enemy_id, spawn_pos,
		_velocity(enemy, int(event.get("y_vel", 0))),
		int(event.get("fixed_move_y", 0)), _scroll_for_slot(enemy_slot),
		int(event.get("event_type", 0)), int(event.get("link_num", 0)), enemy_slot)

	enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
	level_manager.add_child(enemy)

func spawn_sky_enemy(event: Dictionary):
	var enemy_id = int(event.get("enemy_id", 0))
	var enemy = _instantiate(enemy_id)
	if not enemy:
		return

	var spawn_pos = Vector2(
		float(event.get("screen_x", 0)) + 24.0,
		float(event.get("screen_y", 0)))
	var enemy_slot = int(event.get("enemy_slot", 25))

	_setup_enemy(enemy, enemy_id, spawn_pos,
		_velocity(enemy, int(event.get("y_vel", 0))),
		int(event.get("fixed_move_y", 0)), _scroll_for_slot(enemy_slot),
		int(event.get("event_type", 0)), int(event.get("link_num", 0)), enemy_slot)

	enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
	level_manager.add_child(enemy)

func spawn_top_enemy(event: Dictionary):
	var enemy_id = int(event.get("enemy_id", 0))
	var enemy = _instantiate(enemy_id)
	if not enemy:
		return

	var enemy_slot = int(event.get("enemy_slot", 50))

	# Korekta pozycji X i Y (jak w oryginale Tyrian)
	var raw_x = event.get("raw_x", 0)
	var spawn_x = raw_x - (map_x3 - 1) * 24 - 12 - 24
	var y_offset = event.get("y_offset", 0)
	var spawn_y = -28 - back_move3 + y_offset + 34
	if background3x1:
		spawn_y += 4
	if background3x1b:
		spawn_y += 4

	_setup_enemy(enemy, enemy_id, Vector2(float(spawn_x), float(spawn_y)),
		_velocity(enemy, int(event.get("y_vel", 0))),
		int(event.get("fixed_move_y", 0)), _scroll_for_slot(enemy_slot),
		7, int(event.get("link_num", 0)), enemy_slot)

	enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
	level_manager.add_child(enemy)

func spawn_ground_enemy(event: Dictionary):
	var enemy_id = int(event.get("enemy_id", 0))
	var enemy = _instantiate(enemy_id)
	if not enemy:
		return

	var enemy_slot = int(event.get("enemy_slot", 25))
	var spawn_pos = Vector2(
		float(event.get("screen_x", 0)) + 6.0,
		float(event.get("screen_y", 0)) + 3.0)

	_setup_enemy(enemy, enemy_id, spawn_pos,
		_velocity(enemy, int(event.get("y_vel", 0))),
		int(event.get("fixed_move_y", 0)), _scroll_for_slot(enemy_slot),
		int(event.get("event_type", 0)), int(event.get("link_num", 0)), enemy_slot)

	enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
	level_manager.add_child(enemy)

func spawn_ground_enemy_2(event: Dictionary):
	var enemy_id = int(event.get("enemy_id", 0))
	var enemy = _instantiate(enemy_id)
	if not enemy:
		return

	var enemy_slot = int(event.get("enemy_slot", 75))
	var spawn_pos = Vector2(
		float(event.get("screen_x", 0)) + 6.0,
		float(event.get("screen_y", 0)) + 3.0)

	if small_enemy_adjust and enemy.esize == 0:
		spawn_pos.x -= 10
		spawn_pos.y -= 7

	_setup_enemy(enemy, enemy_id, spawn_pos,
		_velocity(enemy, int(event.get("y_vel", 0))),
		int(event.get("fixed_move_y", 0)), _scroll_for_slot(enemy_slot),
		10, int(event.get("link_num", 0)), enemy_slot)

	enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
	level_manager.add_child(enemy)

func spawn_sky_bottom(event: Dictionary):
	var enemy_id = int(event.get("enemy_id", 0))
	var enemy = _instantiate(enemy_id)
	if not enemy:
		return

	var enemy_slot = int(event.get("enemy_slot", 0))
	var spawn_pos = Vector2(
		float(event.get("screen_x", 0)) + 24.0,
		float(event.get("screen_y", 0)))

	_setup_enemy(enemy, enemy_id, spawn_pos,
		_velocity(enemy, int(event.get("y_vel", 0))),
		int(event.get("fixed_move_y", 0)), -int(event.get("back_move2", back_move)),
		int(event.get("event_type", 0)), int(event.get("link_num", 0)), enemy_slot)

	enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
	level_manager.add_child(enemy)

func spawn_sky_bottom2(event: Dictionary):
	var enemy_id = int(event.get("enemy_id", 0))
	var enemy = _instantiate(enemy_id)
	if not enemy:
		return

	var enemy_slot = int(event.get("enemy_slot", 50))
	var spawn_pos = Vector2(
		float(event.get("screen_x", 0)) + 24.0,
		float(event.get("screen_y", 0)))

	_setup_enemy(enemy, enemy_id, spawn_pos,
		_velocity(enemy, int(event.get("y_vel", 0))),
		int(event.get("fixed_move_y", 0)), _scroll_for_slot(enemy_slot),
		int(event.get("event_type", 0)), int(event.get("link_num", 0)), enemy_slot)

	enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
	level_manager.add_child(enemy)

func spawn_ground2_bottom(event: Dictionary):
	var enemy_id = int(event.get("enemy_id", 0))
	var enemy = _instantiate(enemy_id)
	if not enemy:
		return

	var enemy_slot = int(event.get("enemy_slot", 75))
	var spawn_pos = Vector2(
		float(event.get("screen_x", 0)) + 6.0,
		float(event.get("screen_y", 0)) + 3.0)

	if small_enemy_adjust and enemy.esize == 0:
		spawn_pos.x -= 10
		spawn_pos.y -= 7

	_setup_enemy(enemy, enemy_id, spawn_pos,
		_velocity(enemy, int(event.get("y_vel", 0))),
		int(event.get("fixed_move_y", 0)), _scroll_for_slot(enemy_slot),
		56, int(event.get("link_num", 0)), enemy_slot)

	enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
	level_manager.add_child(enemy)

func spawn_enemy_special(event: Dictionary):
	var enemy_id = int(event.get("enemy_id", 0))
	var enemy = _instantiate(enemy_id)
	if not enemy:
		return

	var enemy_slot = int(event.get("enemy_slot", 50))
	var raw_x = event.get("raw_x", 0)
	var spawn_x = raw_x - (map_x3 - 1) * 24 - 12 - 24

	_setup_enemy(enemy, enemy_id, Vector2(float(spawn_x), 190.0),
		_velocity(enemy, int(event.get("y_vel", 0))),
		int(event.get("fixed_move_y", 0)), -back_move3,
		32, int(event.get("link_num", 0)), enemy_slot)

	enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
	level_manager.add_child(enemy)

func spawn_4x4_enemies(event: Dictionary):
	var enemy_ids = event.get("enemy_ids", [])
	var enemy_slot = int(event.get("enemy_slot", 25))
	var fixed_move_y = int(event.get("fixed_move_y", 0))
	var event_type = int(event.get("event_type", 0))
	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	var base_pos = Vector2(
		float(event.get("screen_x", 0)) + 6.0,
		float(event.get("screen_y", 0)) + 3.0 - 28.0)

	# Offsety dla 4x4 gridu (24x28px)
	var offsets = [Vector2(0, 26), Vector2(23, 26), Vector2(0, 0), Vector2(23, 0)]

	for i in range(min(4, enemy_ids.size())):
		var eid = int(enemy_ids[i])
		var enemy = _instantiate(eid)
		if not enemy:
			continue

		var spawn_pos = base_pos + offsets[i]
		if small_enemy_adjust and enemy.esize == 0:
			spawn_pos.x -= 10
			spawn_pos.y -= 7

		_setup_enemy(enemy, eid, spawn_pos,
			_velocity(enemy, int(event.get("y_vel", 0))),
			fixed_move_y, scroll_for_slot,
			event_type, int(event.get("link_num", 0)), enemy_slot)

		enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
		level_manager.add_child(enemy)

# ============================================================================
# Funkcje pomocnicze
# ============================================================================

func _instantiate(enemy_id: int) -> Node2D:
	var scene = _scene_for_enemy(enemy_id)
	if not scene:
		push_error("EnemySpawner: Brak sceny dla enemy_id=%d" % enemy_id)
		return null
	return scene.instantiate()

func _setup_enemy(enemy: Node2D, enemy_id: int, spawn_position: Vector2,
		velocity: Vector2, fixed_move_y: int, scroll_y: int,
		event_type: int, link_num: int, enemy_slot: int) -> void:
	enemy.name           = "Enemy_%d" % enemy_id
	enemy.global_position = spawn_position
	enemy.velocity       = velocity
	enemy.fixed_move_y   = fixed_move_y
	enemy.scroll_y       = scroll_y
	enemy.enemy_id       = enemy_id
	enemy.event_type     = event_type
	enemy.link_num       = link_num
	enemy.enemy_slot     = enemy_slot
	enemy.projectile_scene = GameConstants.enemy_projectile_scene

func _velocity(enemy: Node2D, y_vel: int) -> Vector2:
	return Vector2(float(enemy.xmove), float(enemy.ymove + y_vel))

func _scene_for_enemy(enemy_id: int) -> PackedScene:
	var key = "%03d" % enemy_id
	if _scene_cache.has(key):
		return _scene_cache[key]
	var path = "res://scenes/enemies/Enemy_%s.tscn" % key
	var scene = load(path) if ResourceLoader.exists(path) else null
	_scene_cache[key] = scene
	return scene

func _scroll_for_slot(enemy_slot: int) -> int:
	match enemy_slot:
		0:        return 0
		25, 75:   return back_move
		50:       return back_move3
		_:        return 0
