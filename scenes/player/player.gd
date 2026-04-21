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

# --- Parametry fizyki (klatkowe, jak w Tyrianie) ---
var vel_x: float = 0.0
var vel_y: float = 0.0

# Krok przyspieszenienia i hamowania (piksele/klatkę²)
# Tyrian używa wartości ~1-2 na klatkę
var accel_step: float = 1.5
var friction_step: float = 1.0

# Osobne limity prędkości (z ships.json × skala)
var max_speed_forward: float = 0.0   # na podstawie maneuverability
var max_speed_reverse: float = 0.0   # szybsze cofanie (speed_reverse = 2)

const PIXELS_PER_UNIT: float = 2.0   # skalowanie jednostek Tyriana na piksele Godota
const TYRIAN_FPS: float = 30.0

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
	armor = ship_data.get("armor", 100)
	max_armor = armor

	var maneuv = ship_data.get("maneuverability", 10)
	var spd_fwd = ship_data.get("speed_forward", 1)
	var spd_rev = ship_data.get("speed_reverse", 2)

	# Maneuverability = limit prędkości (im wyższe, tym szybciej może lecieć)
	# speed_forward/reverse to mnożniki kierunkowe
	max_speed_forward = maneuv * spd_fwd * PIXELS_PER_UNIT
	max_speed_reverse = maneuv * spd_rev * PIXELS_PER_UNIT

	# Krok przyspieszenia skalowalny z maneuverability
	accel_step = maneuv * 0.08 * PIXELS_PER_UNIT
	friction_step = accel_step * 0.75  # hamowanie nieco wolniejsze niż przyspieszenie

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
# 2. RUCH I FIZYKA
# ============================================================================

func _physics_process(delta):
	power = min(power_max, power + power_add)

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if Input.is_action_pressed("ui_accept"):
		weapon_system.set_firing(true)
	else:
		weapon_system.set_firing(false)

	# --- Fizyka klatkowa (jak Tyrian) ---
	# Przelicz delta na "klatki Tyriana" żeby zachować niezależność od FPS Godota
	var frame_scale = delta * TYRIAN_FPS

	# Przyspieszanie: stały przyrost w kierunku inputu
	if input_dir.x != 0.0:
		vel_x += input_dir.x * accel_step * frame_scale
	else:
		# Hamowanie: odejmuj stałą wartość w kierunku aktualnej velocity
		if abs(vel_x) <= friction_step * frame_scale:
			vel_x = 0.0
		else:
			vel_x -= sign(vel_x) * friction_step * frame_scale

	if input_dir.y != 0.0:
		vel_y += input_dir.y * accel_step * frame_scale
	else:
		if abs(vel_y) <= friction_step * frame_scale:
			vel_y = 0.0
		else:
			vel_y -= sign(vel_y) * friction_step * frame_scale

	# Limit prędkości: osobny dla przodu (góra) i tyłu (dół)
	# W Tyrianie "przód" to góra ekranu (statek leci w górę)
	if vel_y < 0:  # leci do przodu (góra)
		vel_y = max(vel_y, -max_speed_forward)
	else:          # cofa się (dół)
		vel_y = min(vel_y, max_speed_reverse)

	# Poziomo symetrycznie
	vel_x = clamp(vel_x, -max_speed_forward, max_speed_forward)

	velocity = Vector2(vel_x, vel_y)
	move_and_slide()
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
