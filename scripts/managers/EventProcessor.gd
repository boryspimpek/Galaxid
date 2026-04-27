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

const CONTEXT_EVENT_TYPES = [1, 2, 8, 13, 14, 19, 20, 26, 27, 30, 31]

# Stosuje eventy kontekstowe (scroll, starfield, flagi) przed start_dist,
# pomija spawny — używane przez "Play from dist".
# Jednocześnie śledzi dokładne piksele scrollu każdej warstwy tła,
# żeby seek_to ustawił je precyzyjnie (niezależnie od zmian back_move w trakcie).
func fast_forward_to(target_dist: int):
	var layer_dist1: int = 0
	var layer_dist2: int = 0
	var layer_dist3: int = 0
	var prev_dist:   int = 0
	var i = 0

	while i < level_events.size():
		var event      = level_events[i]
		var event_dist = int(event["dist"])
		if event_dist > target_dist:
			break

		# Piksele każdej warstwy od poprzedniego eventu do tego
		# (używamy OBECNYCH prędkości, ZANIM ten event je zmieni)
		var segment = event_dist - prev_dist
		layer_dist1 += segment * back_move
		layer_dist2 += segment * back_move2
		layer_dist3 += segment * back_move3
		prev_dist = event_dist

		var event_type = int(event["event_type"])
		if event_type in CONTEXT_EVENT_TYPES:
			process_event(event)          # może zmienić back_move/back_move2/back_move3
		elif event.has("enemies_active"):
			enemy_spawner.set_enemies_active(bool(event.get("enemies_active", false)))
		i += 1

	# Reszta dystansu od ostatniego eventu do target_dist
	var remaining = target_dist - prev_dist
	layer_dist1 += remaining * back_move
	layer_dist2 += remaining * back_move2
	layer_dist3 += remaining * back_move3

	current_event_index = i
	print("EventProcessor: fast_forward do dist=", target_dist,
		  ", next_idx=", current_event_index,
		  " (layer_px: ", layer_dist1, " / ", layer_dist2, " / ", layer_dist3, ")")

	# Ustaw warstwy tła na dokładne pozycje
	if background and background.has_method("seek_to"):
		background.seek_to(layer_dist1, layer_dist2, layer_dist3)

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
		1:                    set_starfield_speed(event)
		2, 30:                set_scroll_speed(event)
		8:                    set_starfield_active(event)
		6:                    enemy_spawner.spawn_ground_enemy(event)
		7:                    enemy_spawner.spawn_top_enemy(event)
		10:                   enemy_spawner.spawn_ground_enemy_2(event)
		12:                   enemy_spawner.spawn_4x4_enemies(event)
		13:                   enemy_controller.disable_random_spawn(event)
		14:                   enemy_controller.enable_random_spawn(event)
		15:                   enemy_spawner.spawn_sky_enemy(event)
		17:                   enemy_spawner.spawn_enemy(event)
		18:                   enemy_spawner.spawn_sky_bottom(event)
		23:                   enemy_spawner.spawn_sky_bottom2(event)
		19:                   enemy_controller.enemy_global_move(event)
		20:                   enemy_controller.enemy_global_accel(event)
		26:                   enemy_spawner.set_small_enemy_adjust(bool(event.get("small_enemy_adjust", false)))
		27:                   enemy_controller.enemy_global_accelrev(event)
		31:                   enemy_controller.enemy_fire_override(event)
		32:                   enemy_spawner.spawn_enemy_special(event)
		33:                   enemy_controller.enemy_from_enemy(event)
		56:                   enemy_spawner.spawn_ground2_bottom(event)
		40:                   enemy_controller.enemy_continual_damage(event)
		60:                   enemy_controller.assign_special_enemy(event)
		_:
			pass

	if event.has("enemies_active"):
		enemy_spawner.set_enemies_active(bool(event.get("enemies_active", false)))

func set_starfield_speed(event: Dictionary):
	var speed: int = event.get("starfield_speed", 1)
	if background and background.has_method("set_starfield_speed"):
		background.set_starfield_speed(speed)

func set_starfield_active(event: Dictionary):
	var active: bool = bool(event.get("star_active", true))
	if background and background.has_method("set_starfield_active"):
		background.set_starfield_active(active)

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

	# Aktualizuj scroll_y żyjących wrogów — bez tego dryfują gdy back_move się zmienia
	for enemy in level_manager.get_children():
		if enemy.is_in_group("enemies"):
			match enemy.enemy_slot:
				25, 75: enemy.scroll_y = back_move
				50:     enemy.scroll_y = back_move3

	# Aktualizuj dane w EnemySpawner
	enemy_spawner.set_scroll_data(back_move, back_move3, level_manager.map_x3)

	print("EventProcessor: Set scroll speed: back move=", back_move, ", back move2=", back_move2, ", back move3=", back_move3)
