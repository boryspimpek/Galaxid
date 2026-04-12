extends Node2D

@export var events_file: String = "res://data/lvl17.json"
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

# Referencje
var background: Node2D
var enemies_data: Array = []
var level_events: Array = []
var current_event_index: int = 0

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
			if data.has("lvl_17") and data["lvl_17"].has("events"):
				level_events = data["lvl_17"]["events"]
				level_events.sort_custom(func(a, b): return a["dist"] < b["dist"])
				print("Załadowano ", level_events.size(), " eventów")
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

func process_event(event: Dictionary):
	var event_type = int(event["event_type"])

	match event_type:
		2:                    set_scroll_speed(event)
		6, 15, 17, 18:        spawn_enemy(event)
		12:                   spawn_4x4_enemies(event)
		19:                   enemy_global_move(event)
		20:                   enemy_global_accel(event)
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
