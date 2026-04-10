extends Node2D

@export var events_file: String = "res://data/lvl1.json"
@export var enemies_file: String = "res://data/enemies.json"

@onready var enemy_scene = preload("res://scenes/enemy/Enemy.tscn")

# Stałe z Tyrian
const TYRIAN_FPS  = 15.0
const SCALE_X     = 1280.0 / 320.0   # = 4.0
const SCALE_Y     = 720.0  / 200.0   # = 3.6

# Aktualne prędkości scrollingu (z eventu type 2)
# Wartości w jednostkach Tyrian: piksele/klatkę @ 30 FPS
# Oryginalne wartości domyślne z Tyrian
var back_move:  int = 1   # Tło 1 — Ground (slot 25, 75)
var back_move2: int = 2   # Tło 2 — Sky    (slot 0)
var back_move3: int = 3   # Tło 3 — Top    (slot 50)

# Referencje
var background: Node2D
var enemies_data: Array = []
var level_events: Array = []
var current_event_index: int = 0

# Śledzenie pozycji levelu.
# "dist" w eventach pochodzi z mapYPos, który w Tyrianie rośnie o back_move
# (tło Ground/tło1) na każdą klatkę — NIE back_move2!
var level_distance: float = 0.0

func _ready():
	background = get_node_or_null("../Background")
	load_enemies_data()
	load_events_data()

func _process(delta):
	# Symulacja mapYPos z Tyrian: rośnie o back_move (nie back_move2) na klatkę
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
			if data.has("level_1") and data["level_1"].has("events"):
				level_events = data["level_1"]["events"]
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
		print("DEBUG: DIST REACHED! index=", current_event_index, " event_dist=", event["dist"])
		process_event(event)
		current_event_index += 1

func process_event(event: Dictionary):
	var event_type = int(event["event_type"])
	var event_name = event.get("event_name", "unknown")
	print("DEBUG: process_event type=", event_type, " name=", event_name)

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

	print("Scroll speed: back_move=", back_move,
		  " back_move2=", back_move2, " back_move3=", back_move3)

# ---------------------------------------------------------------------------
# Spawn pojedynczego wroga
# ---------------------------------------------------------------------------

func spawn_enemy(event: Dictionary):
	"""Spawnuje pojedynczego przeciwnika."""
	var enemy_id_raw = event.get("enemy_id", 0)

	var enemy_template = _find_template(enemy_id_raw)
	if enemy_template == null:
		print("ERROR: Nie znaleziono przeciwnika o index=", enemy_id_raw)
		return

	var enemy_id   = int(enemy_template.get("index", 0))
	var enemy_slot = event.get("enemy_slot", 0)
	var event_type = int(event.get("event_type", 0))

	# --- Pozycja ---
	# screen_x / screen_y z JSON-a to już finalne wartości w pikselach Tyrian
	# obliczone przez parser (uwzględniające backMove i y_offset).
	# Wystarczy przeskalować do rozdzielczości Godot.
	var spawn_x = float(event.get("screen_x", 0)) * SCALE_X
	var spawn_y = float(event.get("screen_y", -30)) * SCALE_Y

	# --- Prędkość (surowe jednostki Tyrian: px/klatkę @ 30 FPS) ---
	var xmove          = int(enemy_template.get("xmove", 0))
	var ymove          = int(enemy_template.get("ymove", 0))
	var y_vel          = int(event.get("y_vel", 0))
	var fixed_move_y   = int(event.get("fixed_move_y", 0))
	var raw_velocity   = Vector2(float(xmove), float(ymove + y_vel))

	# --- Prędkość scrollingu dla slotu wroga (surowe jednostki Tyrian) ---
	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	print("DEBUG: Spawning enemy_id=", enemy_id,
		"\n  - Tyrian pos:  (", event.get("screen_x", 0), ",", event.get("screen_y", -30), ")",
		"\n  - Godot pos:   (", spawn_x, ",", spawn_y, ")",
		"\n  - raw vel:     ", raw_velocity, "  fixed_y=", fixed_move_y,
		"\n  - slot=", enemy_slot, "  scroll=", scroll_for_slot)

	var enemy = _create_enemy_node(
		enemy_template, Vector2(spawn_x, spawn_y),
		raw_velocity, fixed_move_y, scroll_for_slot, enemy_id, event_type)

	if enemy:
		get_parent().add_child(enemy)

# ---------------------------------------------------------------------------
# Spawn 4x4
# ---------------------------------------------------------------------------

func spawn_4x4_enemies(event: Dictionary):
	"""Spawnuje 4 wrogów w układzie 2×2 (event type 12)."""
	var enemy_ids  = event.get("enemy_ids", [])
	var enemy_slot = int(event.get("enemy_slot", 25))
	var event_type = int(event.get("event_type", 0))
	var y_vel      = int(event.get("y_vel", 0))
	var fixed_move_y = int(event.get("fixed_move_y", 0))

	# Pozycja bazowa: screen_x/screen_y już w pikselach Tyrian — tylko skalujemy
	var base_x = float(event.get("screen_x", 0)) * SCALE_X
	var base_y = float(event.get("screen_y", -30)) * SCALE_Y

	var scroll_for_slot = _scroll_for_slot(enemy_slot)

	# Offsety formacji 2×2 w pikselach Tyrian, przeskalowane do Godot
	var offsets = [
		Vector2(0,  0),
		Vector2(24, 0),
		Vector2(0,  28),
		Vector2(24, 28),
	]

	for i in range(min(4, enemy_ids.size())):
		var enemy_id_raw   = enemy_ids[i]
		var enemy_template = _find_template(enemy_id_raw)
		if enemy_template == null:
			continue

		# Offsety formacji skalowane identycznie jak pozycja
		var godot_offset = Vector2(offsets[i].x * SCALE_X, offsets[i].y * SCALE_Y)
		var spawn_pos    = Vector2(base_x, base_y) + godot_offset

		var xmove        = int(enemy_template.get("xmove", 0))
		var ymove        = int(enemy_template.get("ymove", 0))
		var raw_velocity = Vector2(float(xmove), float(ymove + y_vel))

		print("DEBUG: 4x4 [", i, "] enemy_id=", enemy_id_raw,
			" pos=", spawn_pos, " raw_vel=", raw_velocity)

		var enemy = _create_enemy_node(
			enemy_template, spawn_pos,
			raw_velocity, fixed_move_y, scroll_for_slot, int(enemy_id_raw), event_type)

		if enemy:
			get_parent().add_child(enemy)

# ---------------------------------------------------------------------------
# Pomocnicze
# ---------------------------------------------------------------------------

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
	"""Tworzy węzeł przeciwnika ze sceny Enemy."""
	var enemy = enemy_scene.instantiate()
	enemy.name = "Enemy_%d" % enemy_id
	enemy.global_position = spawn_position

	# Ustaw parametry z template
	enemy.armor = template.get("armor", 1)
	enemy.esize = template.get("esize", 0)
	enemy.enemy_id = enemy_id
	enemy.event_type = event_type
	enemy.velocity = raw_velocity
	enemy.fixed_move_y = fixed_move_y
	enemy.scroll_y = scroll_for_slot
	
	# Silnik wahadłowy
	enemy.excc = template.get("xcaccel", 0)
	enemy.eycc = template.get("ycaccel", 0)
	enemy.xrev = template.get("xrev", 0)
	enemy.yrev = template.get("yrev", 0)
	enemy.xaccel = template.get("xaccel", 0)
	enemy.yaccel = template.get("yaccel", 0)
	
	# Animacja
	enemy.animate_mode = template.get("animate", 0)
	enemy.ani = template.get("ani", 1)

	return enemy
