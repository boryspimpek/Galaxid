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
	background = get_node_or_null("../Background")
	load_enemies_data()
	load_events_data()

func _process(delta):
	level_distance += float(back_move) * TYRIAN_FPS * delta

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
		event.get("fixed_move_y", 0), scroll_for_slot, enemy_id, event.get("event_type", 0))
	if enemy:
		get_parent().add_child(enemy)

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
			fixed_move_y, scroll_for_slot, int(enemy_ids[i]), event_type)
		if enemy:
			get_parent().add_child(enemy)

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
		scroll_for_slot: int, enemy_id: int = 0, event_type: int = 0) -> Node2D:
	var enemy = enemy_scene.instantiate()
	enemy.name = "Enemy_%d" % enemy_id
	enemy.global_position = spawn_position
	enemy.armor = template.get("armor", 1)
	enemy.esize = template.get("esize", 0)
	enemy.enemy_id = enemy_id
	enemy.event_type = event_type
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
