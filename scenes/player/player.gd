extends CharacterBody2D

# --- Zmienne dynamiczne (zmieniają się w locie) ---
var armor: int = 0
var max_armor: int = 0
var speed: float = 0.0
var velocity_target = Vector2.ZERO

# --- System energii (Power) ---
var power: float = 900.0
var power_max: float = 900.0
var power_add: float = 0.0  # Regeneracja obliczana dynamicznie na podstawie generatora

# --- Parametry fizyki TYRIAN (STAŁY PRZYROST, NIE LERP) ---
var ship_maneuverability: int = 10    # limit prędkości (cap)
var speed_forward: int = 1            # przyrost prędkości do przodu (klatka)
var speed_reverse: int = 1            # przyrost prędkości do tyłu (klatka)
var velocity_x: float = 0.0
var velocity_y: float = 0.0
var ship_data: Dictionary = {}

# --- Systemy (child nodes) ---
@onready var weapon_system: Node = $WeaponSystem
@onready var damage_system: Node = $DamageSystem
@onready var shield_system: Node = $ShieldSystem

# ============================================================================
# 1. INICJALIZACJA (Kolejność ma znaczenie!)
# ============================================================================

func _ready():
	load_ship_data()
	apply_ship_stats()
	init_power_regeneration()
	
	# Opcjonalnie: ustaw stałe 30 FPS dla fizyki (jak w oryginalnym Tyrian)
	# Engine.physics_ticks_per_second = 30

func load_ship_data():
	var s_id = PlayerSetup.ship_id
	var data = DataManager.get_ship_by_id(s_id)
	
	if data:
		ship_data = data
		print("Player: Statek załadowany: ", data.get("name", "Nieznany"))
	else:
		push_error("Player: BŁĄD: Nie znaleziono danych dla statku o ID: " + str(s_id))

func apply_ship_stats():
	# Pancerz
	armor = ship_data.get("armor", 100)
	max_armor = armor
	
	# === NOWA FIZYKA TYRIAN ===
	# Maneuverability = limit prędkości (cap)
	ship_maneuverability = ship_data.get("maneuverability", 10)
	
	# Osobne prędkości dla przodu i tyłu (z ships.json)
	speed_forward = ship_data.get("speed_forward", 1)
	speed_reverse = ship_data.get("speed_reverse", 1)
	
	# Uwaga: stara zmienna 'speed' już nie używana do fizyki, ale zachowana dla kompatybilności
	speed = ship_maneuverability * 30.0
	
	print("Player: Fizyka Tyrian → maneuverability=", ship_maneuverability, 
		  " forward=", speed_forward, " reverse=", speed_reverse)

func init_power_regeneration():
	# Pobierz generator_id z PlayerSetup
	var generator_id = PlayerSetup.generator_id
	
	# Pobierz power z generatora
	var generator_power = DataManager.get_generator_power(generator_id)
	
	# Oblicz power_add dla Godot (60 FPS) na podstawie Tyrian FPS
	# Wzór: (generator_power * TYRIAN_FPS) / 60.0
	power_add = (generator_power * GameConstants.TYRIAN_FPS) / 60.0
	
	print("Player: Generator ID=", generator_id, " power=", generator_power, " → power_add=", power_add, " (energia/klatkę)")

func reload_power_regeneration():
	# Przelicz power_add na podstawie aktualnego generatora
	var generator_id = PlayerSetup.generator_id
	var generator_power = DataManager.get_generator_power(generator_id)
	power_add = (generator_power * GameConstants.TYRIAN_FPS) / 60.0
	print("Player: Przeładowano regenerację energii → power_add=", power_add)

# ============================================================================
# 2. RUCH I FIZYKA (NOWA IMPLEMENTACJA - BEZ LERP)
# ============================================================================

func _physics_process(_delta):
	# Regeneracja energii
	power = min(power_max, power + power_add)
	
	# Pobieranie wektora ruchu
	var input_up = Input.is_action_pressed("ui_up")
	var input_down = Input.is_action_pressed("ui_down")
	var input_left = Input.is_action_pressed("ui_left")
	var input_right = Input.is_action_pressed("ui_right")
	
	# Obsługa strzelania
	if Input.is_action_pressed("ui_accept"):
		weapon_system.set_firing(true)
	else:
		weapon_system.set_firing(false)
	
	# ================================================================
	# FIZYKA TYRIAN: STAŁY PRZYROST PRĘDKOŚCI (BEZ LERP)
	# ================================================================
	
	# Oś Y (przód/tył)
	if input_up:
		if velocity_y > -ship_maneuverability:
			velocity_y -= speed_forward
	elif input_down:
		if velocity_y < ship_maneuverability:
			velocity_y += speed_reverse
	else:
		# Naturalne hamowanie (stała wartość 1 na klatkę)
		if velocity_y > 0:
			velocity_y -= 1
		elif velocity_y < 0:
			velocity_y += 1
	
	# Oś X (lewo/prawo) - używa speed_forward dla obu kierunków (zgodnie z Tyrian)
	if input_left:
		if velocity_x > -ship_maneuverability:
			velocity_x -= speed_forward
	elif input_right:
		if velocity_x < ship_maneuverability:
			velocity_x += speed_forward
	else:
		# Naturalne hamowanie
		if velocity_x > 0:
			velocity_x -= 1
		elif velocity_x < 0:
			velocity_x += 1
	
	# Ograniczenie prędkości do maneuverability (cap)
	velocity_x = clamp(velocity_x, -ship_maneuverability, ship_maneuverability)
	velocity_y = clamp(velocity_y, -ship_maneuverability, ship_maneuverability)
	
	# Aktualizacja pozycji
	# Nie przeliczamy prędkości na FPS, ponieważ ekran i assety są w tej samej skali co oryginał.
	# Statek porusza się z prędkością odczytaną wprost z ships.json (17-25 px/klatkę)
	# i przy rozdzielczości 1280×720 daje to optymalne odczucia.
	
	var speed_multiplier = 1.0
	position.x += velocity_x * speed_multiplier
	position.y += velocity_y * speed_multiplier
	
	# Ograniczenie do ekranu
	_clamp_to_screen()

func _clamp_to_screen():
	# Proste ograniczenie pozycji gracza, aby nie wyleciał za obszar gry
	var screen_size = get_viewport_rect().size
	position.x = clamp(position.x, 32, screen_size.x - 32)
	position.y = clamp(position.y, 32, screen_size.y - 32)

# ============================================================================
# 3. DEBUG
# ============================================================================

func _process(_delta):
	if Input.is_action_just_pressed("ui_home"):
		print("Player: --- DEBUG GRACZA ---")
		print("Player: Statek ID: ", PlayerSetup.ship_id)
		print("Player: Prędkość X/Y: ", velocity_x, "/", velocity_y)
		print("Player: Pancerz: ", armor)
		print("Player: Maneuverability: ", ship_maneuverability)
		print("Player: Speed forward/reverse: ", speed_forward, "/", speed_reverse)