extends CharacterBody2D

# --- 1. STATYSTYKI ZASOBÓW (Z Twojego pseudo-silnika) ---
var power = 900.0
var power_max = 900.0
var power_add = 0.5        # Regeneracja na klatkę

var shield = 50.0
var shield_max = 50.0
var shield_wait = 0        # Licznik klatek do regeneracji
var shield_cost = 20.0     # Koszt energii za 1 pkt tarczy

var armor = 20.0           # Punkty życia (kadłub)

# --- 2. FIZYKA RUCHU (Model Inertia/Friction) ---
var speed = 1200.0
var friction = 0.15
var acceleration = 0.1

# --- 3. SYSTEM BRONI (Loader XML) ---
@export var current_weapon_id: String = "0006"
var weapon_data = {
	"drain": 0.0,
	"repeat": 0,
	"multi": 0,
	"patterns": [] # Lista słowników z danymi <entry>
}
var fire_timer = 0 # Główny licznik szybkostrzelności

@onready var projectile_scene = preload("res://scenes/projectile/Projectile.tscn")

# --- FUNKCJE SILNIKA ---

func _ready():
	# Start na środku dołu ekranu - zaktualizowane dla 1280x720
	global_position = Vector2(640, 600)  # 1280/2 = 640, 720-120 = 600
	# print("DEBUG: current_weapon_id = ", current_weapon_id)
	# Preferuj dane już załadowane przez LevelManager, a gdy go brak — fallback do weapon.json
	load_weapon(current_weapon_id)

func _physics_process(delta):
	# A. REGENERACJA ENERGII
	power = min(power_max, power + power_add)

	# B. REGENERACJA TARCZY
	if shield < shield_max and power >= shield_cost:
		if shield_wait <= 0:
			power -= shield_cost
			shield += 1
			shield_wait = 15 # Odstęp między ładowaniem punktów tarczy
		else:
			shield_wait -= 1

	# C. OBSŁUGA RUCHU (LERP zapewnia płynne "ślizganie się")
	var input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input != Vector2.ZERO:
		velocity = velocity.lerp(input * speed * delta * 60, acceleration)
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction)

	move_and_slide()

	# D. BLOKADA EKRANU (Viewport Clamp) - zaktualizowane dla 1280x720
	position.x = clamp(position.x, 64, 1216)  # 1280/20 = 64, 1280-64 = 1216
	position.y = clamp(position.y, 36, 684)   # 720/20 = 36, 720-36 = 684

	# E. OBSŁUGA FIRE RATE (Kluczowa poprawka)
	if fire_timer > 0:
		fire_timer -= 1
		# if fire_timer % 60 == 0: # Debuguj co sekundę
			# print("DEBUG: fire_timer = ", fire_timer)

	# Sprawdzamy czy puszczamy ogień
	if Input.is_action_pressed("ui_accept") and fire_timer <= 0:
		# print("DEBUG: Power przed strzałem = ", power, " | Drain = ", weapon_data["drain"])
		if power >= weapon_data["drain"]:
			shoot_multi()

# --- LOGIKA STRZELANIA ---

func shoot_multi():
	# Ustawiamy opóźnienie na podstawie shotRepeat z XML
	# Tyrian działał w 30 FPS. Jeśli Godot ma 60 FPS, mnożymy x2,
	# aby zachować oryginalne tempo strzelania.
	fire_timer = weapon_data["repeat"] * 2

	# Odejmujemy koszt energii (drain)
	power -= weapon_data["drain"]
	# print("DEBUG: Power po strzale = ", power)

	# Spacing i Spawning pocisków na podstawie pola 'multi'
	for i in range(weapon_data["multi"]):
		if i < weapon_data["patterns"].size():
			var p = weapon_data["patterns"][i]

			# Ignorujemy puste wpisy w XML (attack=0)
			if p["attack"] <= 0: continue

			var bullet = projectile_scene.instantiate()

			# Przekazujemy parametry do skryptu pocisku
			bullet.damage = p["attack"]
			bullet.velocity = Vector2(p["sx"], -p["sy"]) # -sy bo w górę

			# Pozycja startowa + offset bx/by z XML
			bullet.global_position = $Muzzle.global_position + Vector2(p["bx"], -p["by"])

			get_parent().add_child(bullet)

# --- LOADER JSON (weapon.json) ---

func load_weapon(target_id: String):
	var weapons = _try_get_weapons_data_from_level_manager()
	if weapons != null:
		print("[WEAPON] Źródło: LevelManager.weapons_data")
		load_weapon_from_array(weapons, target_id)
	else:
		print("[WEAPON] Źródło: res://data/weapon.json")
		load_weapon_from_json(target_id)

func _try_get_weapons_data_from_level_manager():
	# Szukamy w drzewie sceny w sposób odporny na nazwy rootów itp.
	var root = get_tree().root
	var lm = root.find_child("LevelManager", true, false)
	if lm == null:
		return null
	if not ("weapons_data" in lm):
		return null
	var wd = lm.weapons_data
	if typeof(wd) != TYPE_ARRAY:
		return null
	return wd

func load_weapon_from_array(weapons: Array, target_id: String):
	var found = null
	for w in weapons:
		if typeof(w) != TYPE_DICTIONARY:
			continue
		if str(w.get("index", "")) == target_id:
			found = w
			break

	if found == null:
		print("BŁĄD: Nie znaleziono broni o index=", target_id, " w weapons_data!")
		weapon_data["drain"] = 0.0
		weapon_data["repeat"] = 0
		weapon_data["multi"] = 0
		weapon_data["patterns"] = []
		return

	weapon_data["drain"] = float(found.get("drain", 0))
	weapon_data["repeat"] = int(found.get("shotRepeat", 0))
	weapon_data["multi"] = int(found.get("multi", 0))

	weapon_data["patterns"] = []
	var patterns = found.get("patterns", [])
	if typeof(patterns) == TYPE_ARRAY:
		for p in patterns:
			if typeof(p) != TYPE_DICTIONARY:
				continue
			var entry = {
				"attack": int(p.get("attack", 0)),
				"bx": float(p.get("bx", 0)),
				"by": float(p.get("by", 0)),
				"sx": float(p.get("sx", 0)),
				"sy": float(p.get("sy", 0))
			}
			weapon_data["patterns"].append(entry)

	print("Uzbrojono: ", target_id, " | Repeat: ", weapon_data["repeat"], " | Multi: ", weapon_data["multi"])

func load_weapon_from_json(target_id: String):
	var file = FileAccess.open("res://data/weapon.json", FileAccess.READ)
	if file == null:
		print("BŁĄD: Nie można otworzyć weapon.json!")
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		print("BŁĄD: Niepoprawny JSON w weapon.json! err=", error)
		return

	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY or not data.has("TyrianHDT"):
		print("BŁĄD: Brak klucza 'TyrianHDT' w weapon.json!")
		return

	var root = data["TyrianHDT"]
	if typeof(root) != TYPE_DICTIONARY or not root.has("weapon"):
		print("BŁĄD: Brak tablicy 'weapon' w weapon.json!")
		return

	var weapons = root["weapon"]
	if typeof(weapons) != TYPE_ARRAY:
		print("BŁĄD: 'TyrianHDT.weapon' nie jest tablicą w weapon.json!")
		return

	load_weapon_from_array(weapons, target_id)
