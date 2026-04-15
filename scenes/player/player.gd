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

# --- Parametry fizyki ---
var acceleration: float = 0.15  # Jak szybko osiąga max prędkość
var friction: float = 0.1      # Jak szybko się zatrzymuje

# --- Słownik na dane statku ---
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
	
	# Prędkość - manewrowość (np. 1-21) przeliczona na piksele/sekundę
	# Mnożnik 30.0 da nam zakres od 30 do 630 px/s
	var maneuverability = ship_data.get("maneuverability", 10)
	speed = maneuverability * 30.0

func init_power_regeneration():
	# Pobierz generator_id z PlayerSetup
	var generator_id = PlayerSetup.generator_id
	
	# Pobierz power z generatora
	var generator_power = DataManager.get_generator_power(generator_id)
	
	# Oblicz power_add dla Godot (60 FPS) na podstawie Tyrian FPS
	# Wzór: (generator_power * TYRIAN_FPS) / 60.0
	power_add = (generator_power * GameConstants.TYRIAN_FPS) / 60.0
	
	print("Player: Generator ID=", generator_id, " power=", generator_power, " → power_add=", power_add, " (energia/klatkę)")

# ============================================================================
# 2. RUCH I FIZYKA
# ============================================================================

func _physics_process(_delta):
	# Regeneracja energii
	power = min(power_max, power + power_add)
	
	# Pobieranie wektora ruchu
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Obsługa strzelania
	if Input.is_action_pressed("ui_accept"):
		weapon_system.set_firing(true)
	else:
		weapon_system.set_firing(false)
	
	# Obliczanie docelowej prędkości (Input * Max Speed)
	var target_velocity = input_dir * speed
	
	# Płynna inercja (Lerp)
	if input_dir != Vector2.ZERO:
		# Przyspieszanie
		velocity = velocity.lerp(target_velocity, acceleration)
	else:
		# Hamowanie
		velocity = velocity.lerp(Vector2.ZERO, friction)
	
	move_and_slide()
	
	# Ograniczenie do ekranu (możesz to też zrobić przez Viewport)
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
		print("Player: Aktualna prędkość: ", velocity.length())
		print("Player: Pancerz: ", armor)
