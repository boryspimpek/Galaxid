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
	# Wczytanie danych z pliku weapons.xml
	load_weapon_from_xml(current_weapon_id)

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

# --- PARSER XML ---

func load_weapon_from_xml(target_id: String):
	var parser = XMLParser.new()
	var err = parser.open("res://data/weapons.xml")
	
	if err != OK:
		print("BŁĄD: Nie znaleziono weapons.xml!")
		return

	var is_correct_weapon = false
	weapon_data["patterns"] = [] # Reset listy przy zmianie broni

	while parser.read() == OK:
		# Debuguj wszystkie node types dla znalezionej broni
		# if is_correct_weapon and parser.get_node_type() == XMLParser.NODE_ELEMENT:
			# print("DEBUG: Node type: ", parser.get_node_type(), " | Node name: ", parser.get_node_name())
		
		# Sprawdzamy koniec definicji broni
		if is_correct_weapon and parser.get_node_type() == XMLParser.NODE_ELEMENT_END and parser.get_node_name() == "weapon":
			is_correct_weapon = false
			break
		
		# Ignorujemy wszystko co nie jest Tagiem (np. spacje/tekst)
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
			
		var node_name = parser.get_node_name()
		
		# Szukamy startu definicji broni: <weapon index="XXXX">
		if node_name == "weapon":
			if parser.get_attribute_value(0) == target_id:
				is_correct_weapon = true
				# print("DEBUG: Znaleziono broń: ", target_id)
				continue
			else:
				is_correct_weapon = false

		if is_correct_weapon:
			# Czytamy parametry główne
			match node_name:
				"drain":
					# print("DEBUG: Znaleziono drain, wartość = ", parser.get_attribute_value(0))
					weapon_data["drain"] = float(parser.get_attribute_value(0))
				"shotRepeat":
					# print("DEBUG: Znaleziono shotRepeat, wartość = ", parser.get_attribute_value(0))
					weapon_data["repeat"] = int(parser.get_attribute_value(0))
				"multi":
					weapon_data["multi"] = int(parser.get_attribute_value(0))
				"entry":
					# Czytamy konkretny wzór pocisku
					var entry = {
						"attack": int(parser.get_attribute_value(0)),
						"bx": float(parser.get_attribute_value(1)),
						"by": float(parser.get_attribute_value(2)),
						"sx": float(parser.get_attribute_value(5)),
						"sy": float(parser.get_attribute_value(6))
					}
					weapon_data["patterns"].append(entry)
					

	print("Uzbrojono: ", target_id, " | Repeat: ", weapon_data["repeat"], " | Multi: ", weapon_data["multi"])
