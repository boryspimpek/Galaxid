@tool
extends EditorScript

const WEAPONS_JSON_PATH = "res://data/weapon.json"
const WEAPON_PORTS_JSON_PATH = "res://data/weapon_ports.json"
const STATS_OUTPUT_DIR = "res://weapons/stats/"
const PORTS_OUTPUT_DIR = "res://weapons/ports/"

var created_stats_resources: Dictionary = {}

func _run() -> void:
	print("--- ROZPOCZĘCIE KONWERSJI JSON -> RESOURCE ---")
	
	_ensure_dir_exists(STATS_OUTPUT_DIR)
	_ensure_dir_exists(PORTS_OUTPUT_DIR)
	
	var weapons_raw = _load_json(WEAPONS_JSON_PATH)
	if weapons_raw:
		print("Pomyślnie wczytano plik weapons.json")
		if weapons_raw.has("TyrianHDT"):
			var w_list = weapons_raw["TyrianHDT"]["weapon"]
			print("Znaleziono ", w_list.size(), " broni w weapons.json")
			_convert_weapons(w_list)
		else:
			print("BŁĄD: JSON nie ma klucza 'TyrianHDT'. Ma klucze: ", weapons_raw.keys())
	else:
		print("BŁĄD: Nie udało się wczytać weapons.json pod ścieżką: ", WEAPONS_JSON_PATH)
		return

	var ports_raw = _load_json(WEAPON_PORTS_JSON_PATH)
	if ports_raw:
		print("Pomyślnie wczytano plik weapon_ports.json")
		if ports_raw.has("weapon_ports"):
			var p_list = ports_raw["weapon_ports"]
			print("Znaleziono ", p_list.size(), " portów w weapon_ports.json")
			_convert_ports(p_list)
		else:
			print("BŁĄD: JSON nie ma klucza 'weapon_ports'. Ma klucze: ", ports_raw.keys())
	else:
		print("BŁĄD: Nie udało się wczytać weapon_ports.json pod ścieżką: ", WEAPON_PORTS_JSON_PATH)
		return
		
	EditorInterface.get_resource_filesystem().scan()
	print("--- KONWERSJA ZAKOŃCZONA SUKCESEM! ---")


func _convert_weapons(weapons_list: Array) -> void:
	var count = 0
	for w_data in weapons_list:
		var idx = int(w_data.get("index", -1))
		if idx <= 0: # Ignorujemy indeks 0 i błędne
			continue
			
		var stats = WeaponStats.new()
		stats.weapon_name = "Weapon_Index_" + str(idx)
		stats.shotRepeat = float(w_data.get("shotRepeat", 0.0))
		stats.multi = int(w_data.get("multi", 0))
		stats.max_level = int(w_data.get("max", 0))
		stats.tx = int(w_data.get("tx", 0))
		stats.ty = int(w_data.get("ty", 0))
		stats.aim = int(w_data.get("aim", 0))
		stats.acceleration = int(w_data.get("acceleration", 0))
		stats.accelerationx = int(w_data.get("accelerationx", 0))
		stats.sound = int(w_data.get("sound", 0))
		stats.trail = int(w_data.get("trail", 255))
		
		if w_data.has("patterns"):
			var pattern_array: Array[WeaponPattern] = []
			for p_data in w_data["patterns"]:
				var pattern = WeaponPattern.new()
				pattern.attack = int(p_data.get("attack", 0))
				pattern.del = int(p_data.get("del", 0))
				pattern.sx = int(p_data.get("sx", 0))
				pattern.sy = int(p_data.get("sy", 0))
				pattern.bx = int(p_data.get("bx", 0))
				pattern.by = int(p_data.get("by", 0))
				pattern.sg = int(p_data.get("sg", 0))
				pattern_array.append(pattern)
			stats.patterns = pattern_array
			
		var save_path = STATS_OUTPUT_DIR + "stats_" + str(idx) + ".tres"
		var error = ResourceSaver.save(stats, save_path)
		if error != OK:
			print("Błąd zapisu stats_" , idx, ": ", error)
		else:
			count += 1
			var saved_res = ResourceLoader.load(save_path)
			if saved_res:
				created_stats_resources[int(idx)] = saved_res
			else:
				created_stats_resources[int(idx)] = stats
			
	print("Zapisano pomyślnie ", count, " plików statystyk (.tres)")


func _convert_ports(ports_list: Array) -> void:
	var count = 0
	for p_data in ports_list:
		var idx = int(p_data.get("index", -1))
		if idx <= 0: 
			continue
			
		var port = WeaponPort.new()
		port.name = str(p_data.get("name", "Unknown"))
		
		if p_data.has("stats"):
			var s = p_data["stats"]
			port.cost = int(s.get("cost", 0))
			port.power_use = int(s.get("power_use", 0))
			port.modes_count = int(s.get("modes_count", 1))
			
		if p_data.has("firing_modes"):
			var fm = p_data["firing_modes"]
			if fm.has("mode_1"):
				var mode_1_resources: Array[WeaponStats] = []
				for id in fm["mode_1"]:
					if int(id) != 0 and created_stats_resources.has(int(id)):
						mode_1_resources.append(created_stats_resources[int(id)])
				port.firing_mode_1 = mode_1_resources
				
			if fm.has("mode_2"):
				var mode_2_resources: Array[WeaponStats] = []
				for id in fm["mode_2"]:
					if int(id) != 0 and created_stats_resources.has(int(id)):
						mode_2_resources.append(created_stats_resources[int(id)])
				port.firing_mode_2 = mode_2_resources
				
		var safe_name = port.name.validate_filename()
		var save_path = PORTS_OUTPUT_DIR + "port_" + str(idx) + "_" + safe_name + ".tres"
		var error = ResourceSaver.save(port, save_path)
		if error != OK:
			print("Błąd zapisu portu ", safe_name, ": ", error)
		else:
			count += 1
			
	print("Zapisano pomyślnie ", count, " plików portów (.tres)")


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(json_string) == OK:
		return json.data
	else:
		print("Błąd wewnętrzny parsowania JSON dla: ", path, " -> ", json.get_error_message())
	return null

func _ensure_dir_exists(path: String) -> void:
	var abs_path = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)
