extends Node

# Singleton - DataManager do centralnego ładowania i cache'owania danych JSON

# Cache danych
var ships_cache: Array = []
var enemies_cache: Array = []
var weapons_cache: Array = []
var shields_cache: Array = []
var weapon_ports_cache: Array = []
var sidekicks_cache: Array = []
var generators_cache: Array = []

# Flaga ładowania
var _ships_loaded: bool = false
var _enemies_loaded: bool = false
var _weapons_loaded: bool = false
var _shields_loaded: bool = false
var _weapon_ports_loaded: bool = false
var _sidekicks_loaded: bool = false
var _generators_loaded: bool = false

# ============================================================================
# PODSTAWOWA FUNKCJA ŁADOWANIA JSON
# ============================================================================

func load_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		push_error("DataManager: Plik nie istnieje: " + file_path)
		return null
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		push_error("DataManager: Błąd JSON w " + file_path + ": " + json.get_error_message())
		return null
	
	return json.get_data()

# ============================================================================
# STATKI (ships.json)
# ============================================================================

func get_ships() -> Array:
	if not _ships_loaded:
		var data = load_json("res://data/ships.json")
		if data:
			ships_cache = data
			_ships_loaded = true
			print("DataManager: Załadowano ", ships_cache.size(), " statków")
	return ships_cache

func get_ship_by_id(id: int) -> Dictionary:
	for ship in get_ships():
		if ship.get("index", 0) == id:
			return ship
	push_error("DataManager: Nie znaleziono statku o ID=", id)
	return {}

# ============================================================================
# PRZECIWNICY (enemies.json)
# ============================================================================

func get_enemies() -> Array:
	if not _enemies_loaded:
		var data = load_json("res://data/enemies.json")
		if data:
			enemies_cache = data
			_enemies_loaded = true
			print("DataManager: Załadowano ", enemies_cache.size(), " przeciwników")
	return enemies_cache

func get_enemy_by_id(id: int) -> Dictionary:
	for enemy in get_enemies():
		if int(enemy.get("index", -1)) == int(id):
			return enemy
	push_error("DataManager: Nie znaleziono przeciwnika o ID=", id)
	return {}

# ============================================================================
# BRONIE (weapon.json)
# ============================================================================

func get_weapons() -> Array:
	if not _weapons_loaded:
		var data = load_json("res://data/weapon.json")
		if data:
			weapons_cache = data.get("TyrianHDT", {}).get("weapon", [])
			_weapons_loaded = true
			print("DataManager: Załadowano ", weapons_cache.size(), " broni")
	return weapons_cache

func get_weapon_by_id(id: int) -> Dictionary:
	for weapon in get_weapons():
		if weapon.get("index") == id:
			return weapon
	push_error("DataManager: Nie znaleziono broni o ID=", id)
	return {}

# ============================================================================
# PORTY BRONI (weapon_ports.json)
# ============================================================================

func get_weapon_ports() -> Array:
	if not _weapon_ports_loaded:
		var data = load_json("res://data/weapon_ports.json")
		if data:
			weapon_ports_cache = data.get("weapon_ports", [])
			_weapon_ports_loaded = true
			print("DataManager: Załadowano ", weapon_ports_cache.size(), " portów broni")
	return weapon_ports_cache

func get_weapon_port_by_id(id: int) -> Dictionary:
	for port in get_weapon_ports():
		if port.get("index", 0) == id:
			return port
	push_error("DataManager: Nie znaleziono portu broni o ID=", id)
	return {}

func get_weapon_firing_index(weapon_port_index: int, mode: int, power_level: int) -> int:
	var port = get_weapon_port_by_id(weapon_port_index)
	if port.is_empty():
		return 0
	
	var firing_modes = port.get("firing_modes", {})
	var mode_key = "mode_" + str(mode)
	var mode_array = firing_modes.get(mode_key, [])
	
	if mode_array.is_empty():
		return 0
	
	# power_level jest 1-11, tablica jest 0-10
	var index = power_level - 1
	if index < 0 or index >= mode_array.size():
		return 0
	
	return mode_array[index]

func get_weapon_power_use(weapon_port_index: int) -> int:
	var port = get_weapon_port_by_id(weapon_port_index)
	if port.is_empty():
		return 0
	
	var stats = port.get("stats", {})
	return stats.get("power_use", 0)

# ============================================================================
# TARCZE (shields.json)
# ============================================================================

func get_shields() -> Array:
	if not _shields_loaded:
		var data = load_json("res://data/shields.json")
		if data:
			shields_cache = data
			_shields_loaded = true
			print("DataManager: Załadowano ", shields_cache.size(), " tarcz")
	return shields_cache

func get_shield_by_id(id: int) -> Dictionary:
	for shield in get_shields():
		if shield.get("index", 0) == id:
			return shield
	push_error("DataManager: Nie znaleziono tarczy o ID=", id)
	return {}

# ============================================================================
# SIDEKICKS (sidekicks.json)
# ============================================================================

func get_sidekicks() -> Array:
	if not _sidekicks_loaded:
		var data = load_json("res://data/sidekicks.json")
		if data:
			sidekicks_cache = data
			_sidekicks_loaded = true
			print("DataManager: Załadowano ", sidekicks_cache.size(), " sidekicków")
	return sidekicks_cache

func get_sidekick_by_id(id: int) -> Dictionary:
	for sidekick in get_sidekicks():
		if sidekick.get("index", 0) == id:
			return sidekick
	push_error("DataManager: Nie znaleziono sidekicka o ID=", id)
	return {}

# ============================================================================
# GENERATORY (generators.json)
# ============================================================================

func get_generators() -> Array:
	if not _generators_loaded:
		var data = load_json("res://data/generators.json")
		if data:
			generators_cache = data
			_generators_loaded = true
			print("DataManager: Załadowano ", generators_cache.size(), " generatorów")
	return generators_cache

func get_generator_by_id(id: int) -> Dictionary:
	for generator in get_generators():
		if generator.get("index", 0) == id:
			return generator
	push_error("DataManager: Nie znaleziono generatora o ID=", id)
	return {}

func get_generator_power(generator_id: int) -> int:
	var generator = get_generator_by_id(generator_id)
	if generator.is_empty():
		return 0
	var stats = generator.get("stats", {})
	return stats.get("power", 0)

# ============================================================================
# POZIOMY (lvl*.json)
# ============================================================================

func get_level_data(level_name: String) -> Dictionary:
	var file_path = "res://data/" + level_name + ".json"
	var data = load_json(file_path)
	if data and data.has(level_name):
		return data[level_name]
	push_error("DataManager: Nie znaleziono danych poziomu: ", level_name)
	return {}

func load_level_data(level_name: String) -> Dictionary:
	var result = {}
	var level_data = get_level_data(level_name)
	
	if not level_data.is_empty():
		if level_data.has("events"):
			result["events"] = level_data["events"]
			result["events"].sort_custom(func(a, b): return a["dist"] < b["dist"])
		else:
			result["events"] = []
		
		if level_data.has("header"):
			result["header"] = level_data["header"]
		else:
			result["header"] = {}
	else:
		result["events"] = []
		result["header"] = {}
	
	return result

# ============================================================================
# CZYSZCZENIE CACHE (do debugowania)
# ============================================================================

func clear_cache():
	ships_cache.clear()
	enemies_cache.clear()
	weapons_cache.clear()
	shields_cache.clear()
	weapon_ports_cache.clear()
	sidekicks_cache.clear()
	generators_cache.clear()
	
	_ships_loaded = false
	_enemies_loaded = false
	_weapons_loaded = false
	_shields_loaded = false
	_weapon_ports_loaded = false
	_sidekicks_loaded = false
	_generators_loaded = false
	
	print("DataManager: Cache wyczyszczony")
