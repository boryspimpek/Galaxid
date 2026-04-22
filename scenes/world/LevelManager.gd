extends Node2D

@export var level_name: String = "lvl17"
@export var events_file: String = "res://data/%s.json" % level_name
@export var enemies_file: String = "res://data/enemies.json"
@export var weapon_file: String = "res://data/weapon.json"

@onready var enemy_scene = preload("res://scenes/enemy/Enemy.tscn")

# Stałe (z GameConstants)
var TYRIAN_FPS  = GameConstants.TYRIAN_FPS

# Prędkości scrollingu (Tyrian px/klatkę)
var back_move:  int = 1   # Ground (slot 25, 75)
var back_move2: int = 2   # Sky (slot 0)
var back_move3: int = 3   # Top (slot 50)

# Flagi tła dla eventów typu 7 (Top Enemy)
var background3x1: bool = false
var background3x1b: bool = false

# Pozycje mapy z nagłówka poziomu
var map_x: int = 1
var map_x2: int = 1
var map_x3: int = 1

# SEKCJA: Referencje do danych
var background: Node2D
var enemies_data: Array = []
var weapons_data: Array = []
var level_events: Array = []
var current_event_index: int = 0

# SEKCJA: Random spawn system
var enemies_active: bool = false
var level_enemy_frequency: int = 96
var level_enemies: Array = []

var random_spawn_timer: float = 0.0

# Pozycja levelu (symulacja mapYPos z Tyrian)
var level_distance: float = 0.0

func _ready():
	background = get_node_or_null("Background")
	load_enemies_data()
	load_weapons_data()
	load_events_data()

func _process(delta):
	level_distance += float(back_move) * TYRIAN_FPS * delta
	process_events_for_distance(int(level_distance))
	process_random_spawn(delta)
	
	if Engine.get_frames_drawn() % 10 == 0:
		print("Dist: ", int(level_distance))
		
func load_enemies_data():
	enemies_data = DataManager.get_enemies()

func load_weapons_data():
	weapons_data = DataManager.get_weapons()

func load_events_data():
	var level_data = DataManager.get_level_data(level_name)
	if not level_data.is_empty():
		if level_data.has("events"):
			level_events = level_data["events"]
			level_events.sort_custom(func(a, b): return a["dist"] < b["dist"])
			print("LevelManager: Załadowano ", level_events.size(), " eventów")
		if level_data.has("header"):
			var header = level_data["header"]
			if header.has("level_enemies"):
				level_enemies = header["level_enemies"]
				print("LevelManager: Załadowano ", level_enemies.size(), " wrogów do random spawn")
			if header.has("map_x"):
				map_x = header["map_x"]
			if header.has("map_x2"):
				map_x2 = header["map_x2"]
			if header.has("map_x3"):
				map_x3 = header["map_x3"]

func process_events_for_distance(dist: int):
	while current_event_index < level_events.size():
		var event = level_events[current_event_index]
		if event["dist"] > dist:
			break
		process_event(event)
		current_event_index += 1

func process_random_spawn(delta: float):
	if not enemies_active or level_enemies.is_empty():
		return

	random_spawn_timer += delta
	if random_spawn_timer < 1.0 / TYRIAN_FPS:
		return
	random_spawn_timer -= 1.0 / TYRIAN_FPS

	if randi() % 100 > level_enemy_frequency:
		var enemy_id = level_enemies[randi() % level_enemies.size()]
		var enemy_template = _find_template(enemy_id)

		if enemy_template == null:
			print("LevelManager: ERROR: Random spawn - nie znaleziono wroga o ID=", enemy_id)
			return

		var startx  = int(enemy_template.get("startx",  0))
		var startxc = int(enemy_template.get("startxc", 0))
		var starty  = int(enemy_template.get("starty",  0))

		var spawn_x = startx
		if startxc != 0:
			spawn_x = startx + (randi() % (startxc * 2)) - startxc + 1

		var spawn_pos = Vector2(float(spawn_x), float(starty))

		var enemy_slot      = int(enemy_template.get("enemy_slot", 25))
		var scroll_for_slot = _scroll_for_slot(enemy_slot)

		var xmove       = int(enemy_template.get("xmove", 0))
		var ymove       = int(enemy_template.get("ymove", 0))
		var raw_velocity = Vector2(float(xmove), float(ymove))

		var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
			0, scroll_for_slot, enemy_id, 0, 0, enemy_slot)
		if enemy:
			enemy.projectile_spawned.connect(_on_enemy_projectile_spawned)
			add_child(enemy)
			# print("LevelManager: Random spawn: wróg ID=", enemy_id, " na pozycji ", spawn_pos)

func process_event(event: Dictionary):
	var event_type = int(event["event_type"])

	match event_type:
		2:                    set_scroll_speed(event)
		6, 15, 17, 18:        spawn_enemy(event)
		7:                    spawn_top_enemy(event)
		10:                   spawn_ground_enemy_2(event)
		12:                   spawn_4x4_enemies(event)
		13:                   disable_random_spawn(event)
		14:                   enable_random_spawn(event)
		19:                   enemy_global_move(event)
		20:                   enemy_global_accel(event)
		27:                   enemy_global_accelrev(event)
		_:
			pass


# --- Scroll speed ---
func set_scroll_speed(event: Dictionary):
	back_move  = event.get("back_move",  back_move)
	back_move2 = event.get("back_move2", back_move2)
	back_move3 = event.get("back_move3", back_move3)

	if background and background.has_method("set_scroll_speed"):
		background.set_scroll_speed(back_move, back_move2, back_move3)
	print("LevelManager: Set scroll speed: back move=", back_move, ", back move2=", back_move2, ", back move3=", back_move3)


# --- Enemy spawn functions ---
func spawn_enemy(event: Dictionary):
	var enemy_id_raw   = event.get("enemy_id", 0)
	var enemy_template = _find_template(enemy_id_raw)
	if enemy_template == null:
		print("LevelManager: ERROR: Nie znaleziono przeciwnika o index=", enemy_id_raw)
		return

	var enemy_id        = int(enemy_template.get("index", 0))
	var enemy_slot      = int(event.get("enemy_slot", 25))
	var spawn_pos       = _calc_spawn_pos(event)
	var raw_velocity    = _calc_velocity(enemy_template, event)
	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
		event.get("fixed_move_y", 0), scroll_for_slot, enemy_id,
		event.get("event_type", 0), event.get("link_num", 0), enemy_slot)
	if enemy:
		enemy.projectile_spawned.connect(_on_enemy_projectile_spawned)
		add_child(enemy)
	print("LevelManager: enemy_id: ", enemy_id, " link_num: ", event.get("link_num", 0))

func spawn_top_enemy(event: Dictionary): # Back_move3
	var enemy_id_raw   = event.get("enemy_id", 0)
	var enemy_template = _find_template(enemy_id_raw)
	if enemy_template == null:
		print("LevelManager: ERROR: Nie znaleziono przeciwnika o index=", enemy_id_raw)
		return

	var enemy_id        = int(enemy_template.get("index", 0))
	var enemy_slot      = int(event.get("enemy_slot", 50)) # Default to top layer
	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	var raw_x    = event.get("raw_x", 0)
	var spawn_x  = raw_x - (map_x3 - 1) * 24 - 12
	var y_offset = event.get("y_offset", 0)
	var spawn_y  = -28 - back_move3 + y_offset

	if background3x1:
		spawn_y += 4
	if background3x1b:
		spawn_y += 4

	var spawn_pos    = Vector2(float(spawn_x), float(spawn_y))
	var xmove        = int(enemy_template.get("xmove", 0))
	var ymove        = int(enemy_template.get("ymove", 0))
	var y_vel        = event.get("y_vel", 0)
	var raw_velocity = Vector2(float(xmove), float(ymove + y_vel))

	var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
		event.get("fixed_move_y", 0), scroll_for_slot, enemy_id, 7,
		event.get("link_num", 0), enemy_slot)
	if enemy:
		enemy.projectile_spawned.connect(_on_enemy_projectile_spawned)
		add_child(enemy)

func spawn_ground_enemy_2(event: Dictionary): # Back_move
	var enemy_id_raw   = event.get("enemy_id", 0)
	var enemy_template = _find_template(enemy_id_raw)
	if enemy_template == null:
		print("LevelManager: ERROR: Nie znaleziono przeciwnika o index=", enemy_id_raw)
		return

	var enemy_id        = int(enemy_template.get("index", 0))
	var enemy_slot      = int(event.get("enemy_slot", 75)) # Default to ground layer
	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	var raw_x    = event.get("raw_x", 0)
	var spawn_x  = raw_x - (map_x - 1) * 24 - 12
	var y_offset = event.get("y_offset", 0)
	var spawn_y  = -28 - back_move + y_offset

	var spawn_pos    = Vector2(float(spawn_x), float(spawn_y))
	var xmove        = int(enemy_template.get("xmove", 0))
	var ymove        = int(enemy_template.get("ymove", 0))
	var y_vel        = event.get("y_vel", 0)
	var raw_velocity = Vector2(float(xmove), float(ymove + y_vel))

	var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
		event.get("fixed_move_y", 0), scroll_for_slot, enemy_id, 10,
		event.get("link_num", 0), enemy_slot)
	if enemy:
		enemy.projectile_spawned.connect(_on_enemy_projectile_spawned)
		add_child(enemy)

func spawn_4x4_enemies(event: Dictionary): # Back_move
	var enemy_ids    = event.get("enemy_ids", [])
	var enemy_slot   = int(event.get("enemy_slot", 25)) # Default to main layer
	var fixed_move_y = int(event.get("fixed_move_y", 0))
	var event_type   = int(event.get("event_type", 0))

	var base_pos        = _calc_spawn_pos(event)
	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	var offsets = [Vector2(0, 0), Vector2(24, 0), Vector2(0, 28), Vector2(24, 28)]

	for i in range(min(4, enemy_ids.size())):
		var enemy_template = _find_template(enemy_ids[i])
		if enemy_template == null:
			continue

		var spawn_pos    = base_pos + Vector2(offsets[i].x, offsets[i].y)
		var raw_velocity = _calc_velocity(enemy_template, event)

		var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
			fixed_move_y, scroll_for_slot, int(enemy_ids[i]), event_type,
			event.get("link_num", 0), enemy_slot)
		if enemy:
			enemy.projectile_spawned.connect(_on_enemy_projectile_spawned)
			add_child(enemy)


# --- Enemy global control ---
func disable_random_spawn(_event: Dictionary):
	enemies_active = false
	print("LevelManager: Random spawn wyłączony")

func enable_random_spawn(_event: Dictionary):
	enemies_active = true
	print("LevelManager: Random spawn włączony")

func enemy_global_accel(event: Dictionary):
	var new_excc  = event.get("new_excc",  -99)
	var new_eycc  = event.get("new_eycc",  -99)
	var link_num  = event.get("link_num",  0)

	print("LevelManager: enemy_global_accel", " link_num: ", link_num)

	for child in get_children():
		if not "enemy_id" in child:
			continue
		if link_num != 0 and child.link_num != link_num:
			continue

		if new_excc != -99:
			child.excc    = new_excc
			child.exccwmax = abs(new_excc) 
			child.exccw = abs(new_excc)
			child.exccadd = 1 if new_excc > 0 else -1
			if child.xrev == 0:
				child.xrev = 100
			# print("SET excc=", child.excc, " exccw=", child.exccw, " exccadd=", child.exccadd)

		if new_eycc != -99:
			child.eycc    = new_eycc
			child.eyccwmax = abs(new_eycc)
			child.eyccw = abs(new_eycc)
			child.eyccadd = 1 if new_eycc > 0 else -1
			if child.yrev == 0:
				child.yrev = 100
			# print("SET eycc=", child.eycc, " eyccw=", child.eyccw, " eyccadd=", child.eyccadd)

func enemy_global_accelrev(event: Dictionary):
	var new_exrev = event.get("new_exrev", -99)
	var new_eyrev = event.get("new_eyrev", -99)
	var link_num  = event.get("link_num",  0)

	for child in get_children():
		if not "enemy_id" in child:
			continue
		if link_num != 0 and child.link_num != link_num:
			continue

		if new_exrev != -99:
			child.xrev = new_exrev
		if new_eyrev != -99:
			child.yrev = new_eyrev

func enemy_global_move(event: Dictionary):
	var new_exc        = event.get("new_exc",         -99)
	var new_eyc        = event.get("new_eyc",         -99)
	var new_fixed_move_y = event.get("new_fixed_move_y", 0)
	var scope_selector = event.get("scope_selector",  0)
	var link_num       = event.get("link_num",        0)

	for child in get_children():
		if not "enemy_id" in child:
			continue

		var in_range = false
		match scope_selector:
			0:   in_range = true
			1:   in_range = (child.enemy_slot >= 25 && child.enemy_slot < 50)
			2:   in_range = (child.enemy_slot < 25)
			3:   in_range = (child.enemy_slot >= 50 && child.enemy_slot < 75)
			99:  in_range = true
			_:   in_range = true

		if not in_range:
			continue

		if scope_selector == 0 or scope_selector >= 80:
			if link_num != 0 and child.link_num != link_num:
				continue

		if new_exc != -99:
			child.velocity.x = float(new_exc)
		if new_eyc != -99:
			child.velocity.y = float(new_eyc)

		if new_fixed_move_y == -99:
			child.fixed_move_y = 0
		elif new_fixed_move_y != 0:
			child.fixed_move_y = new_fixed_move_y


# ========================================
# SEKCJA: Funkcje pomocnicze
# ========================================

func _calc_spawn_pos(event: Dictionary) -> Vector2:
	return Vector2(float(event.get("screen_x", 0)), float(event.get("screen_y", 0)))

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
	var enemy = enemy_scene.instantiate()
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
	# print("LevelManager: Created enemy: ", enemy.name)
	return enemy


# ========================================
# SEKCJA: Callbacks
# ========================================
func _on_enemy_projectile_spawned(projectile):
	# Dodaj pocisk do sceny (jako dziecko LevelManager)
	add_child(projectile)
