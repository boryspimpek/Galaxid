extends Node2D

@export var level_name: String = "lvl17"
@export var events_file: String = "res://data/%s.json" % level_name
@export var enemies_file: String = "res://data/enemies.json"

@onready var enemy_scene = preload("res://scenes/enemy/Enemy.tscn")

# Stałe
const TYRIAN_FPS  = 15.0
const SCALE_X     = 1280.0 / 320.0   # = 4.0
const SCALE_Y     = 720.0  / 200.0   # = 3.6

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

# Referencje
var background: Node2D
var enemies_data: Array = []
var level_events: Array = []
var current_event_index: int = 0

# Random spawn system
var enemies_active: bool = false
var level_enemy_frequency: int = 96
var level_enemies: Array = []
var random_spawn_frame_counter: int = 0

# Pozycja levelu (symulacja mapYPos z Tyrian)
var level_distance: float = 0.0

func _ready():
	background = get_node_or_null("Background")
	load_enemies_data()
	load_events_data()

func _process(delta):
	level_distance += float(back_move) * TYRIAN_FPS * delta

	print("Map position: ", int(level_distance), " | Event index: ", current_event_index, "/", level_events.size())

	process_events_for_distance(int(level_distance))
	process_random_spawn()

func load_enemies_data():
	var file = FileAccess.open(enemies_file, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			enemies_data = json.get_data()
			print("Załadowano ", enemies_data.size(), " przeciwników")
		else:
			push_error("Błąd parsowania JSON przeciwników: " + str(error))
		file.close()
	else:
		push_error("Nie można otworzyć pliku: " + enemies_file)

func load_events_data():
	var file = FileAccess.open(events_file, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			var data = json.get_data()
			if data.has(level_name):
				if data[level_name].has("events"):
					level_events = data[level_name]["events"]
					level_events.sort_custom(func(a, b): return a["dist"] < b["dist"])
					print("Załadowano ", level_events.size(), " eventów")
				if data[level_name].has("header"):
					var header = data[level_name]["header"]
					if header.has("level_enemies"):
						level_enemies = header["level_enemies"]
						print("Załadowano ", level_enemies.size(), " wrogów do random spawn")
					if header.has("map_x"):
						map_x = header["map_x"]
					if header.has("map_x2"):
						map_x2 = header["map_x2"]
					if header.has("map_x3"):
						map_x3 = header["map_x3"]
					print("Pozycje mapy: map_x=", map_x, ", map_x2=", map_x2, ", map_x3=", map_x3)
		else:
			push_error("Błąd parsowania JSON eventów: " + str(error))
		file.close()
	else:
		push_error("Nie można otworzyć pliku: " + events_file)

func process_events_for_distance(dist: int):
	while current_event_index < level_events.size():
		var event = level_events[current_event_index]
		if event["dist"] > dist:
			break
		process_event(event)
		current_event_index += 1

func process_random_spawn():
	if not enemies_active or level_enemies.is_empty():
		return

	# Kompensacja FPS: oryginał 15 FPS, obecnie 60 FPS = stosunek 4
	# Losuj tylko co 4 klatkę
	var fps_ratio = int(Engine.get_frames_per_second() / TYRIAN_FPS)
	random_spawn_frame_counter += 1
	if random_spawn_frame_counter < fps_ratio:
		return
	random_spawn_frame_counter = 0

	# Sprawdź warunek losowania: randi() % 100 > level_enemy_frequency
	if randi() % 100 > level_enemy_frequency:
		# Wybierz losowego wroga z tablicy level_enemies
		var enemy_id = level_enemies[randi() % level_enemies.size()]
		var enemy_template = _find_template(enemy_id)

		if enemy_template == null:
			print("ERROR: Random spawn - nie znaleziono wroga o ID=", enemy_id)
			return

		# Oblicz pozycję startową z danych wroga
		var startx = int(enemy_template.get("startx", 0))
		var startxc = int(enemy_template.get("startxc", 0))
		var starty = int(enemy_template.get("starty", 0))

		# Losowa pozycja X z rozrzutem jeśli startxc != 0
		var spawn_x = startx
		if startxc != 0:
			spawn_x = startx + (randi() % (startxc * 2)) - startxc + 1

		var spawn_y = starty

		# Konwertuj na współrzędne ekranu
		var spawn_pos = Vector2(float(spawn_x) * SCALE_X, float(spawn_y) * SCALE_Y)

		# Użyj slotu Ground (25)
		var enemy_slot = 25
		var scroll_for_slot = _scroll_for_slot(enemy_slot)

		# Oblicz prędkość z danych wroga
		var xmove = int(enemy_template.get("xmove", 0))
		var ymove = int(enemy_template.get("ymove", 0))
		var raw_velocity = Vector2(float(xmove), float(ymove))

		# Utwórz wroga
		var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
			0, scroll_for_slot, enemy_id, 0, 0, enemy_slot)
		if enemy:
			add_child(enemy)
			print("Random spawn: wróg ID=", enemy_id, " na pozycji ", spawn_pos)

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

func set_scroll_speed(event: Dictionary):
	"""Ustawia prędkość scrollingu tła (event type 2)."""
	back_move  = event.get("back_move",  back_move)
	back_move2 = event.get("back_move2", back_move2)
	back_move3 = event.get("back_move3", back_move3)

	if background and background.has_method("set_scroll_speed"):
		background.set_scroll_speed(back_move, back_move2, back_move3)

func spawn_enemy(event: Dictionary):
	var enemy_id_raw = event.get("enemy_id", 0)
	var enemy_template = _find_template(enemy_id_raw)
	if enemy_template == null:
		print("ERROR: Nie znaleziono przeciwnika o index=", enemy_id_raw)
		return

	var enemy_id = int(enemy_template.get("index", 0))
	var spawn_pos = _calc_spawn_pos(event)
	var raw_velocity = _calc_velocity(enemy_template, event)
	var scroll_for_slot = _scroll_for_slot(event.get("enemy_slot", 0))

	var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
		event.get("fixed_move_y", 0), scroll_for_slot, enemy_id, event.get("event_type", 0), event.get("link_num", 0), event.get("enemy_slot", 0))
	if enemy:
		add_child(enemy)

func spawn_top_enemy(event: Dictionary):
	"""Spawns enemy in the Top slot (enemyOffset=50) - event type 7."""
	var enemy_id_raw = event.get("enemy_id", 0)
	var enemy_template = _find_template(enemy_id_raw)
	if enemy_template == null:
		print("ERROR: Nie znaleziono przeciwnika o index=", enemy_id_raw)
		return

	var enemy_id = int(enemy_template.get("index", 0))
	var enemy_slot = 50  # Top slot
	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	# Oblicz pozycję X zgodnie z dokumentacją
	var raw_x = event.get("raw_x", 0)
	var spawn_x = raw_x

	if background3x1:
		spawn_x = raw_x - (map_x - 1) * 24 - 12
	else:
		spawn_x = raw_x - map_x3 * 24 - 24 * 2 + 6

	if background3x1b:
		spawn_x -= 6

	# Oblicz pozycję Y zgodnie z dokumentacją
	var y_offset = event.get("y_offset", 0)
	var spawn_y = -28 - back_move3

	if background3x1b:
		spawn_y += 4  # korekta do -24

	spawn_y += y_offset

	# Konwertuj na współrzędne ekranu
	var spawn_pos = Vector2(float(spawn_x) * SCALE_X, float(spawn_y) * SCALE_Y)

	# Oblicz prędkość
	var xmove = int(enemy_template.get("xmove", 0))
	var ymove = int(enemy_template.get("ymove", 0))
	var y_vel = event.get("y_vel", 0)
	var raw_velocity = Vector2(float(xmove), float(ymove + y_vel))

	# Utwórz wroga
	var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
		event.get("fixed_move_y", 0), scroll_for_slot, enemy_id, 7, event.get("link_num", 0), enemy_slot)
	if enemy:
		add_child(enemy)

func spawn_ground_enemy_2(event: Dictionary):
	"""Spawns enemy in the Ground2 slot (enemyOffset=75) - event type 10."""
	var enemy_id_raw = event.get("enemy_id", 0)
	var enemy_template = _find_template(enemy_id_raw)
	if enemy_template == null:
		print("ERROR: Nie znaleziono przeciwnika o index=", enemy_id_raw)
		return

	var enemy_id = int(enemy_template.get("index", 0))
	var enemy_slot = 75  # Ground2 slot
	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	# Oblicz pozycję X zgodnie z dokumentacją (identyczny wzór jak Event 6)
	var raw_x = event.get("raw_x", 0)
	var spawn_x = raw_x - (map_x - 1) * 24 - 12

	# Oblicz pozycję Y zgodnie z dokumentacją
	var y_offset = event.get("y_offset", 0)
	var spawn_y = -28 - back_move + y_offset

	# Konwertuj na współrzędne ekranu
	var spawn_pos = Vector2(float(spawn_x) * SCALE_X, float(spawn_y) * SCALE_Y)

	# Oblicz prędkość
	var xmove = int(enemy_template.get("xmove", 0))
	var ymove = int(enemy_template.get("ymove", 0))
	var y_vel = event.get("y_vel", 0)
	var raw_velocity = Vector2(float(xmove), float(ymove + y_vel))

	# Utwórz wroga
	var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
		event.get("fixed_move_y", 0), scroll_for_slot, enemy_id, 10, event.get("link_num", 0), enemy_slot)
	if enemy:
		add_child(enemy)

func spawn_4x4_enemies(event: Dictionary):
	var enemy_ids = event.get("enemy_ids", [])
	var enemy_slot = int(event.get("enemy_slot", 25))
	var fixed_move_y = int(event.get("fixed_move_y", 0))
	var event_type = int(event.get("event_type", 0))

	var base_pos = _calc_spawn_pos(event)
	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	var offsets = [Vector2(0, 0), Vector2(24, 0), Vector2(0, 28), Vector2(24, 28)]

	for i in range(min(4, enemy_ids.size())):
		var enemy_template = _find_template(enemy_ids[i])
		if enemy_template == null:
			continue

		var spawn_pos = base_pos + Vector2(offsets[i].x * SCALE_X, offsets[i].y * SCALE_Y)
		var raw_velocity = _calc_velocity(enemy_template, event)

		var enemy = _create_enemy_node(enemy_template, spawn_pos, raw_velocity,
			fixed_move_y, scroll_for_slot, int(enemy_ids[i]), event_type, event.get("link_num", 0), enemy_slot)
		if enemy:
			add_child(enemy)

func disable_random_spawn(event: Dictionary):
	"""Wyłącza losowy spawn wrogów (event type 13)."""
	enemies_active = false
	print("Random spawn wyłączony")

func enable_random_spawn(event: Dictionary):
	"""Włącza losowy spawn wrogów (event type 14)."""
	enemies_active = true
	print("Random spawn włączony")

func enemy_global_accel(event: Dictionary):
	"""Modyfikuje silnik wahadłowy (excc/eycc) grupy wrogów (event type 20)."""
	var new_excc = event.get("new_excc", -99)
	var new_eycc = event.get("new_eycc", -99)
	var link_num = event.get("link_num", 0)

	for child in get_children():
		if not "enemy_id" in child:  # Check if it's an Enemy node
			continue

		# Filtruj po link_num (0 = wszyscy)
		if link_num != 0 and child.link_num != link_num:
			continue

		# Zmień excc (pełny reset stanu wahadła)
		if new_excc != -99:
			child.excc = new_excc
			child.exccw = abs(new_excc)
			child.exccwmax = child.exccw
			child.exccadd = 1 if new_excc > 0 else -1
			if child.xrev == 0:
				child.xrev = 100

		# Zmień eycc (bez resetu stanu wahadła)
		if new_eycc != -99:
			child.eycc = new_eycc

func enemy_global_accelrev(event: Dictionary):
	"""Zmienia limity prędkości wahadła (exrev/eyrev) grupy wrogów (event type 27)."""
	var new_exrev = event.get("new_exrev", -99)
	var new_eyrev = event.get("new_eyrev", -99)
	var link_num = event.get("link_num", 0)

	for child in get_children():
		if not "enemy_id" in child:  # Check if it's an Enemy node
			continue

		# Filtruj po link_num (0 = wszyscy)
		if link_num != 0 and child.link_num != link_num:
			continue

		# Zmień exrev (limit prędkości X)
		if new_exrev != -99:
			child.xrev = new_exrev

		# Zmień eyrev (limit prędkości Y)
		if new_eyrev != -99:
			child.yrev = new_eyrev


func enemy_global_move(event: Dictionary):
	"""Modyfikuje prędkość ruchu wrogów (event type 19)."""
	var new_exc = event.get("new_exc", -99)
	var new_eyc = event.get("new_eyc", -99)
	var new_fixed_move_y = event.get("new_fixed_move_y", 0)
	var scope_selector = event.get("scope_selector", 0)
	var link_num = event.get("link_num", 0)

	for child in get_children():
		if not "enemy_id" in child:  # Check if it's an Enemy node
			continue

		# Sprawdzenie zakresu wrogów (scope_selector)
		var in_range = false
		match scope_selector:
			0:   in_range = true  # wszyscy
			1:   in_range = (child.enemy_slot >= 25 && child.enemy_slot < 50)  # Ground
			2:   in_range = (child.enemy_slot < 25)  # Sky
			3:   in_range = (child.enemy_slot >= 50 && child.enemy_slot < 75)  # Top
			99:  in_range = true  # wszyscy
			_:   in_range = true  # domyślnie wszyscy

		if not in_range:
			continue

		# Filtrowanie po link_num (tylko gdy scope_selector == 0 lub >= 80)
		if scope_selector == 0 or scope_selector >= 80:
			if link_num != 0 and child.link_num != link_num:
				continue

		# Zmień exc (prędkość X)
		if new_exc != -99:
			child.velocity.x = float(new_exc)

		# Zmień eyc (prędkość Y)
		if new_eyc != -99:
			child.velocity.y = float(new_eyc)

		# Zmień fixed_move_y
		if new_fixed_move_y == -99:
			child.fixed_move_y = 0  # reset do 0
		elif new_fixed_move_y != 0:
			child.fixed_move_y = new_fixed_move_y  # ustaw nową wartość
		# wartość 0 pozostawia fixed_movey bez zmian

# Pomocnicze

func _calc_spawn_pos(event: Dictionary) -> Vector2:
	return Vector2(float(event.get("screen_x", 0)) * SCALE_X, float(event.get("screen_y", 0)) * SCALE_Y)

func _calc_velocity(template: Dictionary, event: Dictionary) -> Vector2:
	var xmove = int(template.get("xmove", 0))
	var ymove = int(template.get("ymove", 0))
	var y_vel = int(event.get("y_vel", 0))
	return Vector2(float(xmove), float(ymove + y_vel))

func _find_template(enemy_id_raw) -> Dictionary:
	for template in enemies_data:
		if int(template.get("index", -1)) == int(enemy_id_raw):
			return template
	return {}

func _scroll_for_slot(enemy_slot: int) -> int:
	"""Zwraca prędkość scrollingu (Tyrian px/klatkę) właściwą dla slotu."""
	match enemy_slot:
		0:        return back_move2   # Sky
		25, 75:   return back_move    # Ground
		50:       return back_move3   # Top
		_:        return back_move2

func _create_enemy_node(template: Dictionary, spawn_position: Vector2,
		raw_velocity: Vector2, fixed_move_y: int,
		scroll_for_slot: int, enemy_id: int = 0, event_type: int = 0, link_num: int = 0, enemy_slot: int = 0) -> Node2D:
	var enemy = enemy_scene.instantiate()
	enemy.name = "Enemy_%d" % enemy_id
	enemy.global_position = spawn_position
	enemy.armor = template.get("armor", 1)
	enemy.esize = template.get("esize", 0)
	enemy.enemy_id = enemy_id
	enemy.event_type = event_type
	enemy.link_num = link_num
	enemy.enemy_slot = enemy_slot
	enemy.velocity = raw_velocity
	enemy.fixed_move_y = fixed_move_y
	enemy.scroll_y = scroll_for_slot
	enemy.excc = template.get("xcaccel", 0)
	enemy.eycc = template.get("ycaccel", 0)
	enemy.xrev = template.get("xrev", 0)
	enemy.yrev = template.get("yrev", 0)
	enemy.xaccel = template.get("xaccel", 0)
	enemy.yaccel = template.get("yaccel", 0)
	return enemy
