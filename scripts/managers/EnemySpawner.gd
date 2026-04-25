extends Node

# Klasa odpowiedzialna za tworzenie wrogów i random spawn

# Referencje do danych
var level_manager: Node2D
var enemies_data: Array = []
var enemy_scene: PackedScene
var level_name: String = ""
var _scene_cache: Dictionary = {}  # enemy_id_str -> PackedScene | null

# Dane scrollingu i mapy
var back_move: int = 1
var back_move3: int = 3
var map_x: int = 1
var map_x3: int = 1
var background3x1: bool = false
var background3x1b: bool = false
var small_enemy_adjust: bool = false

# Random spawn system
var enemies_active: bool = false
var level_enemy_frequency: int = 96
var level_enemies: Array = []
var random_spawn_timer: float = 0.0

func _init(p_level_manager: Node2D, p_enemies_data: Array, p_enemy_scene: PackedScene, p_level_name: String = ""):
	level_manager = p_level_manager
	enemies_data = p_enemies_data
	enemy_scene = p_enemy_scene
	level_name = p_level_name

func set_scroll_data(p_back_move: int, p_back_move3: int, p_map_x: int, p_map_x3: int):
	back_move = p_back_move
	back_move3 = p_back_move3
	map_x = p_map_x
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

func process_random_spawn(_delta: float): # Delta ignorowana
	if not enemies_active or level_enemies.is_empty():
		return

	# W TYM SYSTEMIE TA FUNKCJA WYKONUJE SIĘ RAZ NA KLATKĘ (30 FPS).
	# Szansa na spawn w danej klatce (identycznie jak w oryginale)
	if randi() % 100 > level_enemy_frequency:
		var enemy_id = level_enemies[randi() % level_enemies.size()]
		var enemy_template = _find_template(enemy_id)

		if enemy_template == null:
			return

		# Logika pozycji (startx, startxc, starty) - zostaje bez zmian
		var startx  = int(enemy_template.get("startx",  0))
		var startxc = int(enemy_template.get("startxc", 0))
		var starty  = int(enemy_template.get("starty",  0))

		var spawn_x = startx
		if startxc != 0:
			spawn_x = startx + (randi() % (startxc * 2)) - startxc + 1

		# Używamy float dla Godota, ale wartości pochodzą z int-ów Tyriana
		var spawn_pos = Vector2(float(spawn_x), float(starty))

		# Pobieranie prędkości (xmove, ymove) - to są piksele na klatkę!
		var xmove = int(enemy_template.get("xmove", 0))
		var ymove = int(enemy_template.get("ymove", 0))
		var raw_velocity = Vector2(float(xmove), float(ymove))

		var enemy_slot = int(enemy_template.get("enemy_slot", 25))
		var scroll_for_slot = _scroll_for_slot(enemy_slot)

		# Tworzenie wroga - przesyłasz "czyste" wartości bez mnożenia przez deltę
		var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
			0, scroll_for_slot, enemy_id, 0, 0, enemy_slot)
			
		if enemy:
			enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
			level_manager.add_child(enemy)

func spawn_enemy(event: Dictionary):
	var enemy_id_raw   = event.get("enemy_id", 0)
	var enemy_template = _find_template(enemy_id_raw)
	if enemy_template == null:
		print("EnemySpawner: ERROR: Nie znaleziono przeciwnika o index=", enemy_id_raw)
		return

	var enemy_id = int(enemy_template.get("index", 0))
	var enemy_slot = int(event.get("enemy_slot", 25))
	var spawn_pos = _calc_spawn_pos(event, enemy_template)
	var raw_velocity = _calc_velocity(enemy_template, event)
	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
		event.get("fixed_move_y", 0), scroll_for_slot, enemy_id,
		event.get("event_type", 0), event.get("link_num", 0), enemy_slot)
	if enemy:
		enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
		level_manager.add_child(enemy)
	# print("EnemySpawner: enemy_id: ", enemy_id, " link_num: ", event.get("link_num", 0))

func spawn_sky_enemy(event: Dictionary):
	var enemy_id_raw   = event.get("enemy_id", 0)
	var enemy_template = _find_template(enemy_id_raw)
	if enemy_template == null:
		print("EnemySpawner: ERROR: Nie znaleziono przeciwnika o index=", enemy_id_raw)
		return

	var enemy_id = int(enemy_template.get("index", 0))
	var enemy_slot = int(event.get("enemy_slot", 25))

	# Użyj screen_x i screen_y już przeliczonych przez parser
	# Dodaj korektę pozycji
	var spawn_x = event.get("screen_x", 0) + 24
	var spawn_y = event.get("screen_y", 0)
	var spawn_pos = Vector2(float(spawn_x), float(spawn_y))

	var raw_velocity = _calc_velocity(enemy_template, event)
	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
		event.get("fixed_move_y", 0), scroll_for_slot, enemy_id,
		event.get("event_type", 0), event.get("link_num", 0), enemy_slot)
	if enemy:
		enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
		level_manager.add_child(enemy)
	# print("EnemySpawner: enemy_id: ", enemy_id, " link_num: ", event.get("link_num", 0))

func spawn_top_enemy(event: Dictionary):
	var enemy_id_raw   = event.get("enemy_id", 0)
	var enemy_template = _find_template(enemy_id_raw)
	if enemy_template == null:
		print("EnemySpawner: ERROR: Nie znaleziono przeciwnika o index=", enemy_id_raw)
		return

	var enemy_id = int(enemy_template.get("index", 0))
	var enemy_slot = int(event.get("enemy_slot", 50))
	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	# Niewiadomo dlaczego ale trzeba dodać -24px do x, żeby wyrównać spawn 
	# oraz + 34px do y aby wyrównać spawn z mapą
	var raw_x = event.get("raw_x", 0)
	var spawn_x = raw_x - (map_x3 - 1) * 24 - 12 - 24
	var y_offset = event.get("y_offset", 0) 
	var spawn_y = -28 - back_move3 + y_offset + 34

	if background3x1:
		spawn_y += 4
	if background3x1b:
		spawn_y += 4

	var spawn_pos = Vector2(float(spawn_x), float(spawn_y))
	var xmove = int(enemy_template.get("xmove", 0))
	var ymove = int(enemy_template.get("ymove", 0))
	var y_vel = event.get("y_vel", 0)
	var raw_velocity = Vector2(float(xmove), float(ymove + y_vel))

	var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
		event.get("fixed_move_y", 0), scroll_for_slot, enemy_id, 7,
		event.get("link_num", 0), enemy_slot)
	if enemy:
		enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
		level_manager.add_child(enemy)

func spawn_ground_enemy(event: Dictionary):
	var enemy_id_raw   = event.get("enemy_id", 0)
	var enemy_template = _find_template(enemy_id_raw)
	if enemy_template == null:
		print("EnemySpawner: ERROR: Nie znaleziono przeciwnika o index=", enemy_id_raw)
		return

	var enemy_id = int(enemy_template.get("index", 0))
	var enemy_slot = int(event.get("enemy_slot", 25))

	# Użyj screen_x i screen_y już przeliczonych przez parser
	# Dodaj korektę pozycji
	var spawn_x = event.get("screen_x", 0) + 6
	var spawn_y = event.get("screen_y", 0) + 3
	var spawn_pos = Vector2(float(spawn_x), float(spawn_y))
	
	var raw_velocity = _calc_velocity(enemy_template, event)
	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
		event.get("fixed_move_y", 0), scroll_for_slot, enemy_id,
		event.get("event_type", 0), event.get("link_num", 0), enemy_slot)
	if enemy:
		enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
		level_manager.add_child(enemy)
	# print("EnemySpawner: enemy_id: ", enemy_id, " link_num: ", event.get("link_num", 0))


func spawn_ground_enemy_2(event: Dictionary):
	var enemy_id_raw   = event.get("enemy_id", 0)
	var enemy_template = _find_template(enemy_id_raw)
	if enemy_template == null:
		print("EnemySpawner: ERROR: Nie znaleziono przeciwnika o index=", enemy_id_raw)
		return

	var enemy_id = int(enemy_template.get("index", 0))
	var enemy_slot = int(event.get("enemy_slot", 75))
	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	# Użyj screen_x i screen_y już przeliczonych przez parser
	# Dodaj korektę pozycji
	var spawn_x = event.get("screen_x", 0) + 6
	var spawn_y = event.get("screen_y", 0) + 3
	var spawn_pos = Vector2(float(spawn_x), float(spawn_y))
	
	# Korekta smallEnemyAdjust (jak w oryginale Tyrian)
	if small_enemy_adjust and int(enemy_template.get("esize", 0)) == 0:
		spawn_pos.x -= 10
		spawn_pos.y -= 7
	
	var xmove = int(enemy_template.get("xmove", 0))
	var ymove = int(enemy_template.get("ymove", 0))
	var y_vel = event.get("y_vel", 0)
	var raw_velocity = Vector2(float(xmove), float(ymove + y_vel))

	var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
		event.get("fixed_move_y", 0), scroll_for_slot, enemy_id, 10,
		event.get("link_num", 0), enemy_slot)
	if enemy:
		enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
		level_manager.add_child(enemy)

func spawn_4x4_enemies(event: Dictionary):
	var enemy_ids = event.get("enemy_ids", [])
	var enemy_slot = int(event.get("enemy_slot", 25))
	var fixed_move_y = int(event.get("fixed_move_y", 0))
	var event_type = int(event.get("event_type", 0))

	# Użyj screen_x i screen_y już przeliczonych przez parser
	# Dodaj korektę pozycji
	var spawn_x = event.get("screen_x", 0) + 6
	var spawn_y = event.get("screen_y", 0) + 3
	var base_pos = Vector2(float(spawn_x), float(spawn_y))

	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	# Offsety dla 4x4 gridu (24x28px), celowo zmieniona kolejność, 
	# i przesuniete do srodka, aby nie było szpar
	var offsets = [Vector2(0, 26), Vector2(23, 26), Vector2(0, 0), Vector2(23, 0)]

	for i in range(min(4, enemy_ids.size())):
		var enemy_template = _find_template(enemy_ids[i])
		if enemy_template == null:
			continue

		var spawn_pos = base_pos + Vector2(offsets[i].x, offsets[i].y)
		
		# Korekta smallEnemyAdjust (jak w oryginale Tyrian) - dla każdego wroga osobno
		if small_enemy_adjust and int(enemy_template.get("esize", 0)) == 0:
			spawn_pos.x -= 10
			spawn_pos.y -= 7
		
		var raw_velocity = _calc_velocity(enemy_template, event)

		var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
			fixed_move_y, scroll_for_slot, int(enemy_ids[i]), event_type,
			event.get("link_num", 0), enemy_slot)
		if enemy:
			enemy.projectile_spawned.connect(level_manager._on_enemy_projectile_spawned)
			level_manager.add_child(enemy)

# Funkcje pomocnicze

func _calc_spawn_pos(event: Dictionary, template) -> Vector2:
	var pos = Vector2(float(event.get("screen_x", 0)), float(event.get("screen_y", 0)))
	if small_enemy_adjust and template != null and int(template.get("esize", 0)) == 0:
		pos.x -= 10
		pos.y -= 7
	return pos

func _calc_velocity(template: Dictionary, event: Dictionary) -> Vector2:
	var xmove = int(template.get("xmove", 0))
	var ymove = int(template.get("ymove", 0))
	var y_vel = int(event.get("y_vel", 0))
	return Vector2(float(xmove), float(ymove + y_vel))

func _find_template(enemy_id_raw):
	for template in enemies_data:
		if int(template.get("index", -1)) == int(enemy_id_raw):
			return template
	return null

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

func _create_enemy_node(template: Dictionary, spawn_position: Vector2,
		raw_velocity: Vector2, fixed_move_y: int,
		scroll_for_slot: int, enemy_id: int = 0, event_type: int = 0,
		link_num: int = 0, enemy_slot: int = 0) -> Node2D:
	var scene = _scene_for_enemy(enemy_id)
	var enemy = scene.instantiate() if scene else enemy_scene.instantiate()
	enemy.name          = "Enemy_%d" % enemy_id
	enemy.global_position = spawn_position
	enemy.armor         = template.get("armor",   1)
	enemy.esize         = template.get("esize",   0)
	enemy.enemy_id      = enemy_id
	enemy.event_type    = event_type
	enemy.link_num      = link_num
	enemy.enemy_slot    = enemy_slot
	enemy.velocity      = raw_velocity
	enemy.fixed_move_y  = fixed_move_y
	enemy.scroll_y      = scroll_for_slot
	enemy.excc          = template.get("xcaccel", 0)
	enemy.eycc          = template.get("ycaccel", 0)
	enemy.xrev          = template.get("xrev",    0)
	enemy.yrev          = template.get("yrev",    0)
	enemy.xaccel        = template.get("xaccel",  0)
	enemy.yaccel        = template.get("yaccel",  0)
	enemy.tur           = template.get("tur",     [0, 0, 0])
	enemy.freq          = template.get("freq",    [0, 0, 0])
	enemy.projectile_scene = GameConstants.enemy_projectile_scene
	return enemy
