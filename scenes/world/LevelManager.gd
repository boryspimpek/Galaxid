extends Node2D

# Preload klas menedżerów
const EnemySpawner = preload("res://scripts/managers/EnemySpawner.gd")
const EnemyController = preload("res://scripts/managers/EnemyController.gd")
const EventProcessor = preload("res://scripts/managers/EventProcessor.gd")

# Główny plik z eventami - SCENARIUSZ POZIOMU, tu ustawiamy 
# w ktory poziom gracz ma grać
@export var level_name: String = "lvl17"

# Uwaga: enemies.json nie jest już używany w runtime — dane wrogów są osadzone w scenach Enemy_XXX.tscn


# Prędkości scrollingu (Tyrian px/klatkę)
var back_move:  int = 1   # Ground (slot 25, 75)
var back_move2: int = 2   # Sky (slot 0)
var back_move3: int = 3   # Top (slot 50)

# Pozycje mapy z nagłówka poziomu
var map_x: int = 1
var map_x2: int = 1
var map_x3: int = 1
var map_y: int = 0

# SEKCJA: Referencje do danych
var background: Node2D

# SEKCJA: Menedżery
var enemy_spawner: EnemySpawner
var enemy_controller: EnemyController
var event_processor: EventProcessor

# Pozycja levelu (symulacja mapYPos z Tyrian)
var level_distance: float = 0.0

# Flagi globalne (eventy środowiskowe)
var enemy_continual_damage: bool = false

func _ready():
	background = get_node_or_null("Background")

	# Debug: plugin może narzucić level i start_dist przez ProjectSettings.
	# level_name trzeba nadpisać PRZED init_managers(), bo tam jest load_data().
	var start_dist: int = ProjectSettings.get_setting("game/debug/start_dist", 0)
	if start_dist > 0:
		var debug_level: String = ProjectSettings.get_setting("game/debug/level_name", "")
		if debug_level != "":
			level_name = debug_level

	init_managers()
	if background and background.has_method("setup"):
		background.setup(level_name, back_move, back_move2, back_move3, map_x, map_x2, map_x3, map_y)

	if start_dist > 0:
		level_distance = float(start_dist)
		event_processor.fast_forward_to(start_dist)  # seek_to tła wywołane wewnętrznie

func _process(_delta):
	level_distance += float(back_move)
	event_processor.process_events_for_distance(int(level_distance))
	enemy_spawner.process_random_spawn(_delta)
	
	if Engine.get_frames_drawn() % 100 == 0:
		print("Dist: ", int(level_distance))
		
func load_data():
	DataManager.get_weapons()  # pre-cache broni przed pierwszym strzałem

	var level_data = DataManager.load_level_data(level_name)
	if not level_data.is_empty():
		print("LevelManager: Załadowano ", level_data["events"].size(), " eventów")
		if level_data["header"].has("level_enemies"):
			print("LevelManager: Załadowano ", level_data["header"]["level_enemies"].size(), " wrogów do random spawn")
		if level_data["header"].has("map_x"):
			map_x = level_data["header"]["map_x"]
		if level_data["header"].has("map_x2"):
			map_x2 = level_data["header"]["map_x2"]
		if level_data["header"].has("map_x3"):
			map_x3 = level_data["header"]["map_x3"]
		if level_data["header"].has("map_y"):
			map_y = level_data["header"]["map_y"]
	return level_data

func init_managers():
	var level_data = load_data()

	enemy_spawner = EnemySpawner.new(self)
	enemy_controller = EnemyController.new(self)
	event_processor = EventProcessor.new(self, background, enemy_spawner, enemy_controller)

	event_processor.set_level_events(level_data["events"])
	event_processor.set_scroll_data(back_move, back_move2, back_move3)

	enemy_spawner.set_scroll_data(back_move, back_move3)
	if level_data["header"].has("level_enemies"):
		enemy_spawner.set_random_spawn_data(level_data["header"]["level_enemies"])



# ========================================
# SEKCJA: Callbacks
# ========================================
func _on_enemy_projectile_spawned(projectile):
	# Dodaj pocisk do sceny (jako dziecko LevelManager)
	add_child(projectile)
