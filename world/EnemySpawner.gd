extends Node2D

@export var events_file: String = "res://data/events.json"
@export var enemies_file: String = "res://data/enemies.json"

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
var background: ParallaxBackground
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
		raw_velocity, fixed_move_y, scroll_for_slot, enemy_id)

	if enemy:
		get_parent().add_child(enemy)

# ---------------------------------------------------------------------------
# Spawn 4x4
# ---------------------------------------------------------------------------

func spawn_4x4_enemies(event: Dictionary):
	"""Spawnuje 4 wrogów w układzie 2×2 (event type 12)."""
	var enemy_ids  = event.get("enemy_ids", [])
	var enemy_slot = int(event.get("enemy_slot", 25))
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
			raw_velocity, fixed_move_y, scroll_for_slot, int(enemy_id_raw))

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
		scroll_for_slot: int, enemy_id: int = 0) -> Node2D:
	"""Tworzy węzeł przeciwnika z kolorowym placeholderem."""
	var enemy = Node2D.new()
	enemy.name = "Enemy_%d" % enemy_id
	enemy.global_position = spawn_position
	enemy.z_index = 100

	# Placeholder: kolorowe kółko
	var colors = [
		Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW,
		Color.CYAN, Color.MAGENTA, Color.ORANGE, Color.PURPLE
	]
	var circle   = Polygon2D.new()
	circle.name  = "Visual"
	circle.color = colors[enemy_id % colors.size()]
	var pts      = PackedVector2Array()
	var radius   = 12.0
	for i in range(16):
		var a = i * TAU / 16.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	circle.polygon = pts
	circle.z_index = 100
	enemy.add_child(circle)

	# Label debugowy
	var label = Label.new()
	label.name = "DebugLabel"
	label.text = str(enemy_id)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-10, -10)
	label.size     = Vector2(20, 20)
	label.z_index = 200
	label.add_theme_font_size_override("font_size", 50)
	label.add_theme_color_override("font_color", Color.BLACK)
	enemy.add_child(label)

	# Kolizja
	var collision      = CollisionShape2D.new()
	var circle_shape   = CircleShape2D.new()
	circle_shape.radius = radius
	collision.shape    = circle_shape
	enemy.add_child(collision)

	# Skrypt ruchu
	var enemy_script = GDScript.new()
	enemy_script.source_code = _generate_enemy_script(
		template, raw_velocity, fixed_move_y, scroll_for_slot)
	enemy_script.reload()
	enemy.set_script(enemy_script)

	return enemy

# ---------------------------------------------------------------------------
# Generowanie skryptu wroga
# ---------------------------------------------------------------------------

func _generate_enemy_script(template: Dictionary, raw_velocity: Vector2,
		fixed_move_y: int, scroll_for_slot: int) -> String:

	var armor   = template.get("armor",   1)
	var esize   = template.get("esize",   0)
	var animate = template.get("animate", 0)
	var ani     = template.get("ani",     1)

	var xcaccel = template.get("xcaccel", 0)
	var ycaccel = template.get("ycaccel", 0)
	var xrev    = template.get("xrev",    0)
	var yrev    = template.get("yrev",    0)
	var xaccel  = template.get("xaccel",  0)
	var yaccel  = template.get("yaccel",  0)

	# raw_velocity i scroll_for_slot są w jednostkach Tyrian (px/klatkę @ 30 FPS).
	# Przeliczenie na px/s Godot odbywa się w _process wroga:
	#   godot_px_per_s = tyrian_px_per_frame * SCALE * TYRIAN_FPS
	# Dzięki temu silnik wahadłowy (który operuje na surowych jednostkach Tyrian)
	# działa poprawnie — modyfikuje velocity przed skalowaniem.

	var src = """extends Node2D

# ---- Stałe przeliczeniowe ----
const TYRIAN_FPS = 15.0
const SCALE_X    = 1280.0 / 320.0   # = 4.0
const SCALE_Y    = 720.0  / 200.0   # = 3.6

# ---- Statystyki ----
var armor: int = {armor}
var esize: int = {esize}

# ---- Ruch (surowe jednostki Tyrian: px/klatkę @ 30 FPS) ----
# velocity odpowiada exc/eyc z silnika Tyrian
var velocity:      Vector2 = Vector2({vel_x}, {vel_y})
var fixed_move_y:  int     = {fixed_y}
# Prędkość scrollingu właściwa dla slotu tego wroga (px/klatkę Tyrian)
var scroll_y:      int     = {scroll_for_slot}

# ---- Silnik wahadłowy (xcaccel / ycaccel) ----
var excc:     int = {xcaccel}
var eycc:     int = {ycaccel}
var exrev:    int = {xrev}
var eyrev:    int = {yrev}
var exccw:    int = 0
var eyccw:    int = 0
var exccwmax: int = 0
var eyccwmax: int = 0
var exccadd:  int = 1
var eyccadd:  int = 1

# ---- Losowe przyspieszenie ----
var xaccel: int = {xaccel}
var yaccel: int = {yaccel}

# ---- Animacja ----
var animate_mode: int = {animate}
var ani:          int = {ani}
var enemycycle:   int = 0
var animin:       int = 0
var aniactive:    int = 0
var animax:       int = 0
var aniwhenfire:  int = 0

# ---- Granice usuwania (px Godot) ----
const BOUNDS_LEFT   = -1400
const BOUNDS_RIGHT  = 1480
const BOUNDS_TOP    = -1000
const BOUNDS_BOTTOM = 1000

func _ready():
	# Inicjalizacja silnika wahadłowego X
	if excc != 0:
		exccw    = abs(excc)
		exccwmax = exccw
		exccadd  = 1 if excc > 0 else -1
		if exrev == 0:
			exrev = 100

	# Inicjalizacja silnika wahadłowego Y
	if eycc != 0:
		eyccw    = abs(eycc)
		eyccwmax = eyccw
		eyccadd  = 1 if eycc > 0 else -1
		if eyrev == 0:
			eyrev = 100

	# Inicjalizacja animacji
	match animate_mode:
		0:  # Brak animacji
			aniactive  = 0
			animin     = 0
			enemycycle = 1
		1:  # Zawsze aktywna
			aniactive  = 1
			animin     = 0
			enemycycle = 0
		2:  # Tylko przy strzale
			aniactive  = 2
			animin     = 0
			animax     = ani
			enemycycle = 1
			aniwhenfire = 2

func _process(delta):
	# Kolejność zgodna z JE_drawEnemy w Tyrianie:
	# 1. fixed_move_y
	# 2. velocity (eyc) — po ewentualnej aktualizacji silnika wahadłowego
	# 3. scroll tła (tempBackMove)

	# --- 1. Silnik wahadłowy X ---
	if excc != 0:
		exccw -= 1
		if exccw <= 0:
			velocity.x += exccadd
			exccw = exccwmax
			if velocity.x == exrev:
				excc    = -excc
				exrev   = -exrev
				exccadd = -exccadd

	# --- 2. Silnik wahadłowy Y ---
	if eycc != 0:
		eyccw -= 1
		if eyccw <= 0:
			velocity.y += eyccadd
			eyccw = eyccwmax
			if velocity.y == eyrev:
				eycc    = -eycc
				eyrev   = -eyrev
				eyccadd = -eyccadd

	# --- 3. Przeliczenie na px/s Godot i zastosowanie ruchu ---
	# Każdy składnik (fixed, velocity, scroll) jest w px/klatkę Tyrian.
	# Przeliczamy: tyrian_px_per_frame * scale * TYRIAN_FPS = godot_px_per_s
	var move_x = (velocity.x)                          * SCALE_X * TYRIAN_FPS
	var move_y = (float(fixed_move_y) + velocity.y + float(scroll_y)) * SCALE_Y * TYRIAN_FPS

	position.x += move_x * delta
	position.y += move_y * delta

	# --- 4. Usuń poza ekranem ---
	if position.x < BOUNDS_LEFT or position.x > BOUNDS_RIGHT:
		#print("DEBUG: ", name, " removed (X bounds): ", position.x)
		queue_free()
	if position.y < BOUNDS_TOP  or position.y > BOUNDS_BOTTOM:
		#print("DEBUG: ", name, " removed (Y bounds): ", position.y)
		queue_free()

	# --- 5. Animacja ---
	if aniactive > 0:
		enemycycle += 1
		if enemycycle > ani:
			enemycycle = animin
		update_animation()

func update_animation():
	# TODO: aktualizacja klatki na podstawie enemycycle
	pass

func take_damage(damage: int):
	armor -= damage
	if armor <= 0:
		explode()

func explode():
	# TODO: efekt eksplozji
	queue_free()
"""

	return src.format({
		"armor":           armor,
		"esize":           esize,
		"vel_x":           raw_velocity.x,
		"vel_y":           raw_velocity.y,
		"fixed_y":         fixed_move_y,
		"scroll_for_slot": scroll_for_slot,
		"xcaccel":         int(xcaccel),
		"ycaccel":         int(ycaccel),
		"xrev":            int(xrev),
		"yrev":            int(yrev),
		"xaccel":          int(xaccel),
		"yaccel":          int(yaccel),
		"animate":         animate,
		"ani":             ani,
	})
