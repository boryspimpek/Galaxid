extends Node2D

# Preload klas menedżerów
const EnemySpawner = preload("res://scripts/managers/EnemySpawner.gd")
const EnemyController = preload("res://scripts/managers/EnemyController.gd")
const EventProcessor = preload("res://scripts/managers/EventProcessor.gd")

# Główny plik z eventami - SCENARIUSZ POZIOMU, tu ustawiamy 
# w ktory poziom gracz ma grać
@export var level_name: String = "lvl17"

# Ścieżki do plików z danymi
@export var events_file: String = "res://data/%s.json" % level_name
@export var enemies_file: String = "res://data/enemies.json"
@export var weapon_file: String = "res://data/weapon.json"

@onready var enemy_scene = preload("res://scenes/enemy/Enemy.tscn")


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

# SEKCJA: Menedżery
var enemy_spawner: EnemySpawner
var enemy_controller: EnemyController
var event_processor: EventProcessor

# Pozycja levelu (symulacja mapYPos z Tyrian)
var level_distance: float = 0.0

func _ready():
	background = get_node_or_null("Background")
	load_data()
	init_managers()

func _process(_delta):
	level_distance += float(back_move)
	event_processor.process_events_for_distance(int(level_distance))
	enemy_spawner.process_random_spawn(_delta)
	
	# if Engine.get_frames_drawn() % 10 == 0:
	# 	print("Dist: ", int(level_distance))
		
func load_data():
	enemies_data = DataManager.get_enemies()
	weapons_data = DataManager.get_weapons()

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

		# Preload tekstur wyłączony — tekstury ładowane przez sceny Enemy_XXX.tscn
		# _preload_level_textures(level_data)
		return level_data
	return {}

func _preload_level_textures(level_data: Dictionary) -> void:
	var ids: Dictionary = {}
	for id in level_data["header"].get("level_enemies", []):
		ids[int(id)] = true
	for event in level_data["events"]:
		if event.has("enemy_id"):
			ids[int(event["enemy_id"])] = true
		for id in event.get("enemy_ids", []):
			ids[int(id)] = true
	var sprites_folder = "res://data/enemy_sprites"
	DataManager.preload_enemy_textures(sprites_folder, ids.keys())

func init_managers():
	enemy_spawner = EnemySpawner.new(self, enemies_data, enemy_scene, level_name)
	enemy_controller = EnemyController.new(self)
	event_processor = EventProcessor.new(self, background, enemy_spawner, enemy_controller)
	
	var level_data = DataManager.load_level_data(level_name)
	event_processor.set_level_events(level_data["events"])
	event_processor.set_scroll_data(back_move, back_move2, back_move3)
	
	enemy_spawner.set_scroll_data(back_move, back_move3, map_x, map_x3)
	enemy_spawner.set_background_flags(background3x1, background3x1b)
	if level_data["header"].has("level_enemies"):
		enemy_spawner.set_random_spawn_data(level_data["header"]["level_enemies"])



# ========================================
# SEKCJA: Callbacks
# ========================================
func _on_enemy_projectile_spawned(projectile):
	# Dodaj pocisk do sceny (jako dziecko LevelManager)
	add_child(projectile)
