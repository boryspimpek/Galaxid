extends Node

# Preload klas
const EnemySpawner = preload("res://scripts/managers/EnemySpawner.gd")
const EnemyController = preload("res://scripts/managers/EnemyController.gd")

# Klasa odpowiedzialna za przetwarzanie eventów poziomu

var level_manager: Node2D
var background: Node2D
var enemy_spawner: EnemySpawner
var enemy_controller: EnemyController

var level_events: Array = []
var current_event_index: int = 0

# Dane scrollingu
var back_move: int = 1
var back_move2: int = 2
var back_move3: int = 3

func _init(p_level_manager: Node2D, p_background: Node2D, p_enemy_spawner: EnemySpawner, p_enemy_controller: EnemyController):
	level_manager = p_level_manager
	background = p_background
	enemy_spawner = p_enemy_spawner
	enemy_controller = p_enemy_controller

func set_level_events(p_events: Array):
	level_events = p_events
	current_event_index = 0

func set_scroll_data(p_back_move: int, p_back_move2: int, p_back_move3: int):
	back_move = p_back_move
	back_move2 = p_back_move2
	back_move3 = p_back_move3

const CONTEXT_EVENT_TYPES = [2]

# Stosuje eventy kontekstowe (scroll, starfield, flagi) przed start_dist,
# pomija spawny — używane przez "Play from dist".
# Jednocześnie śledzi dokładne piksele scrollu każdej warstwy tła,
# żeby seek_to ustawił je precyzyjnie (niezależnie od zmian back_move w trakcie).
func fast_forward_to(target_dist: int):
	# layer_distX to piksele przesunięcia każdej warstwy.
	# Kluczowa zależność: level_distance += back_move/kl. i scroll_y -= back_move/kl.,
	# więc layer1_scroll == level_distance (bez mnożenia!).
	# Layer2/3 muszą być przeliczone przez liczbę klatek w segmencie:
	#   frames = segment / back_move
	#   layerN_scroll = frames * back_moveN = segment * back_moveN / back_move
	var layer_dist1: float = 0.0
	var layer_dist2: float = 0.0
	var layer_dist3: float = 0.0
	var prev_dist:   int   = 0
	var i = 0

	while i < level_events.size():
		var event      = level_events[i]
		var event_dist = int(event["dist"])
		if event_dist > target_dist:
			break

		# Piksele każdej warstwy w tym segmencie
		# (używamy OBECNYCH prędkości, ZANIM ten event je zmieni)
		var segment = event_dist - prev_dist
		layer_dist1 += float(segment)
		if back_move > 0:
			layer_dist2 += float(segment) * float(back_move2) / float(back_move)
			layer_dist3 += float(segment) * float(back_move3) / float(back_move)
		prev_dist = event_dist

		var event_type = int(event["event_type"])
		if event_type in CONTEXT_EVENT_TYPES:
			process_event(event)          # może zmienić back_move/back_move2/back_move3
		# elif event.has("enemies_active"):
		# 	enemy_spawner.set_enemies_active(bool(event.get("enemies_active", false)))
		i += 1

	# Reszta dystansu od ostatniego eventu do target_dist
	var remaining = target_dist - prev_dist
	layer_dist1 += float(remaining)
	if back_move > 0:
		layer_dist2 += float(remaining) * float(back_move2) / float(back_move)
		layer_dist3 += float(remaining) * float(back_move3) / float(back_move)

	var px1 := int(layer_dist1)
	var px2 := int(layer_dist2)
	var px3 := int(layer_dist3)

	current_event_index = i
	print("EventProcessor: fast_forward do dist=", target_dist,
		  ", next_idx=", current_event_index,
		  " (layer_px: ", px1, " / ", px2, " / ", px3, ")")

	# Ustaw warstwy tła na dokładne pozycje
	if background and background.has_method("seek_to"):
		background.seek_to(px1, px2, px3)

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
		100:                  enemy_spawner.spawn_path_enemy(event)
		200:                  enemy_spawner.spawn_free_enemy(event)
		201:                  enemy_spawner.spawn_free_4x4(event)
		202:                  enemy_spawner.just_spawn_enemy(event)
		204:                  enemy_spawner.spawn_formation(event)
		300:                  enemy_controller.enemy_fire_power(event)
		_:
			pass

	if event.has("enemies_active"):
		enemy_spawner.set_enemies_active(bool(event.get("enemies_active", false)))

func set_scroll_speed(event: Dictionary):
	back_move  = event.get("back_move",  back_move)
	back_move2 = event.get("back_move2", back_move2)
	back_move3 = event.get("back_move3", back_move3)

	# Synchronizuj LevelManager — bez tego level_distance rośnie o 1/kl.
	# zamiast o back_move/kl., a eventy odpalają się 2× za późno względem pozycji mapy
	level_manager.back_move  = back_move
	level_manager.back_move3 = back_move3

	if background and background.has_method("set_scroll_speed"):
		background.set_scroll_speed(back_move, back_move2, back_move3)

	# Aktualizuj dane w EnemySpawner
	enemy_spawner.set_scroll_data(back_move, back_move3)

	print("EventProcessor: Set scroll speed: back move=", back_move, ", back move2=", back_move2, ", back move3=", back_move3)
