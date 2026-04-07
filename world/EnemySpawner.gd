extends Node2D

# --- Dane i stan ---
var level_spawns = [] # Tu przechowujemy tylko listę spawnu dla aktualnego poziomu
var enemy_shapes_data = {}
var distance_traveled = 0.0

# --- Stałe silnika Tyrian ---
const TYRIAN_FPS = 30.0
const SCROLL_SPEED_BASE = 10.0
var current_scroll_velocity = SCROLL_SPEED_BASE * TYRIAN_FPS

func _ready():
	print("DEBUG: Inicjalizacja zoptymalizowanego systemu spawnu")
	load_enemy_shapes_data()
	load_level_data("level_1") # Możesz tu dynamicznie zmieniać poziom

func load_level_data(level_id: String):
	# np. level_id = "level_1"
	var path = "res://data/" + level_id + ".json"
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("BŁĄD: Nie znaleziono pliku")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	# POPRAWKA: Używamy char(0) zamiast "\x00"
	json_text = json_text.replace(char(0), "")
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error == OK:
		var full_data = json.data
		# Reszta logiki bez zmian...
		if full_data.has(level_id):
			level_spawns = full_data[level_id].get("spawns", [])
			level_spawns.sort_custom(func(a, b): return a["dist"] < b["dist"])
			print("DEBUG: Załadowano ", level_spawns.size(), " eventów.")
	else:
		print("BŁĄD PARSOWANIA JSON w linii ", json.get_error_line(), ": ", json.get_error_message())

func _process(delta):
	# Aktualizacja dystansu
	distance_traveled += current_scroll_velocity * delta
	
	# Sprawdzanie spawnu
	check_and_spawn_enemies()

func check_and_spawn_enemies():
	# Sprawdzamy tylko przód kolejki (najbliższe zdarzenie)
	# Używamy while, na wypadek gdyby kilka wrogów miało ten sam 'dist'
	while level_spawns.size() > 0 and distance_traveled >= level_spawns[0].get("dist", 0):
		var event = level_spawns.pop_front() # Pobiera i usuwa z listy - bardzo wydajne
		
		var enemy_id = event.get("enemy_id", 0)
		var x = event.get("x", 0)
		
		# Filtrowanie śmieciowych danych i wartości specjalnych
		if is_valid_event(enemy_id, x):
			spawn_enemy(enemy_id, x, event)

func is_valid_event(id: int, x: int) -> bool:
	# Tyrian używa wysokich ID (np. > 4000) lub ujemnych dla komend logicznych
	# Ignorujemy je na etapie spawnowania fizycznych wrogów
	if id <= 0 or id > 4000:
		return false
	# Ignorujemy wrogów spawnowanych daleko poza marginesem ekranu (oryginał 0-320, teraz 0-1280)
	if x < -100 or x > 420:
		return false
	return true

func spawn_enemy(enemy_id: int, x: int, full_event_data: Dictionary):
	# Pobieranie danych kształtu wroga
	var enemy_data = get_enemy_shape_data(enemy_id)
	if not enemy_data:
		return
	
	# Przeliczenie pozycji X z oryginalnego ekranu 320x240 na aktualny 1280x720
	var original_width = 320
	var current_width = 1280
	var scale_factor = float(current_width) / float(original_width)
	var scaled_x = x * scale_factor
	
	# Tworzenie instancji przeciwnika
	var enemy_scene = preload("res://scenes/projectile/Projectile.tscn")
	var enemy_instance = enemy_scene.instantiate()
	
	# Ustawianie pozycji i właściwości
	enemy_instance.position = Vector2(scaled_x, 100) # Spawn na środku ekranu
	
	# Ustawianie sprite'a
	if enemy_instance.has_node("Sprite2D"):
		var sprite = enemy_instance.get_node("Sprite2D")
		sprite.texture = load(enemy_data.sprite_path)
		sprite.scale = Vector2(enemy_data.scale, enemy_data.scale)
	
	add_child(enemy_instance)

func get_enemy_shape_data(enemy_id: int) -> Dictionary:
	# Przeszukujemy enemy_shapes_data w poszukiwaniu odpowiedniego ID
	if enemy_shapes_data.has("enemy_mapping"):
		for enemy in enemy_shapes_data["enemy_mapping"]:
			if enemy.get("id") == enemy_id:
				return enemy
	return {}

func load_enemy_shapes_data():
	var file = FileAccess.open("res://data/enemy_shapes.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			enemy_shapes_data = json.data
		file.close()
