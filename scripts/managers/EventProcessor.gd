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
		6, 15, 17, 18:        enemy_spawner.spawn_enemy(event)
		7:                    enemy_spawner.spawn_top_enemy(event)
		10:                   enemy_spawner.spawn_ground_enemy_2(event)
		12:                   enemy_spawner.spawn_4x4_enemies(event)
		13:                   enemy_controller.disable_random_spawn(event)
		14:                   enemy_controller.enable_random_spawn(event)
		19:                   enemy_controller.enemy_global_move(event)
		20:                   enemy_controller.enemy_global_accel(event)
		26:                   enemy_spawner.set_small_enemy_adjust(bool(event.get("small_enemy_adjust", false)))
		27:                   enemy_controller.enemy_global_accelrev(event)
		_:
			pass

func set_scroll_speed(event: Dictionary):
	back_move  = event.get("back_move",  back_move)
	back_move2 = event.get("back_move2", back_move2)
	back_move3 = event.get("back_move3", back_move3)

	if background and background.has_method("set_scroll_speed"):
		background.set_scroll_speed(back_move, back_move2, back_move3)
	
	# Aktualizuj dane w EnemySpawner
	enemy_spawner.set_scroll_data(back_move, back_move3, level_manager.map_x, level_manager.map_x3)
	
	print("EventProcessor: Set scroll speed: back move=", back_move, ", back move2=", back_move2, ", back move3=", back_move3)
