extends CharacterBody2D

# --- Zmienne dynamiczne (zmieniają się w locie) ---
var armor: int = 0
var max_armor: int = 0

# --- System energii (Power) ---
var power: float = 900.0
var power_max: float = 900.0
var power_add: float = 0.0

# --- Fizyka ruchu (identyczna dla wszystkich statków, jak w oryginale Tyrian) ---
const SPEED_CAP: int = 4
const ACCEL: int = 1
const FRICTION: int = 2

var velocity_x: float = 0.0
var velocity_y: float = 0.0
var ship_data: Dictionary = {}

# --- Sterowanie myszką ---
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _use_mouse: bool = false

# --- Systemy (child nodes) ---
@onready var weapon_system: Node = $WeaponSystem
@onready var damage_system: Node = $DamageSystem
@onready var shield_system: Node = $ShieldSystem

# ============================================================================
# 1. INICJALIZACJA (Kolejność ma znaczenie!)
# ============================================================================

func _ready():
	add_to_group("player")
	# Warstwa 1 = gracz; pociski wroga muszą mieć maskę 1 żeby go wykryć
	collision_layer = 1
	collision_mask  = 0
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
	var stats = ship_data.get("stats", {})
	armor = stats.get("armor", 10)
	max_armor = armor
	print("Player: Ship → armor=", armor)

func init_power_regeneration():
	var generator_id = PlayerSetup.generator_id
	var generator_power = DataManager.get_generator_power(generator_id)
	power_add = generator_power
	print("Player: Generator ID=", generator_id, " power=", generator_power, " → power_add=", power_add, " (energia/klatkę)")

func reload_power_regeneration():
	# Przelicz power_add na podstawie aktualnego generatora
	var generator_id = PlayerSetup.generator_id
	var generator_power = DataManager.get_generator_power(generator_id)
	power_add = generator_power
	print("Player: Przeładowano regenerację energii → power_add=", power_add)

# ============================================================================
# 2. RUCH I FIZYKA (NOWA IMPLEMENTACJA - BEZ LERP)
# ============================================================================

func _physics_process(_delta):
	# Regeneracja energii
	power = min(power_max, power + power_add)

	# --- Wykrywanie aktywnego schematu sterowania ---
	var mouse_pos = get_global_mouse_position()
	var any_key = Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down") \
				or Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")

	if mouse_pos != _last_mouse_pos:
		_use_mouse = true
	if any_key:
		_use_mouse = false
	_last_mouse_pos = mouse_pos

	# Obsługa strzelania (myszka lub klawiatura)
	var firing = Input.is_action_pressed("ui_accept") \
			  or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	weapon_system.set_firing(firing)

	if _use_mouse:
		# ====================================================================
		# STEROWANIE MYSZKĄ: bezpośrednia pozycja – brak bezwładności
		# ====================================================================
		position = mouse_pos
		velocity_x = 0.0
		velocity_y = 0.0
	else:
		# ====================================================================
		# FIZYKA TYRIAN: STAŁY PRZYROST PRĘDKOŚCI (BEZ LERP)
		# ====================================================================
		var input_up    = Input.is_action_pressed("ui_up")
		var input_down  = Input.is_action_pressed("ui_down")
		var input_left  = Input.is_action_pressed("ui_left")
		var input_right = Input.is_action_pressed("ui_right")

		# Oś X
		if input_left:
			if velocity_x > 0:
				velocity_x -= FRICTION
			elif velocity_x > -SPEED_CAP:
				velocity_x -= ACCEL
		elif input_right:
			if velocity_x < 0:
				velocity_x += FRICTION
			elif velocity_x < SPEED_CAP:
				velocity_x += ACCEL
		else:
			velocity_x = move_toward(velocity_x, 0, FRICTION)

		# Oś Y
		if input_up:
			if velocity_y > 0:
				velocity_y -= FRICTION
			elif velocity_y > -SPEED_CAP:
				velocity_y -= ACCEL
		elif input_down:
			if velocity_y < 0:
				velocity_y += FRICTION
			elif velocity_y < SPEED_CAP:
				velocity_y += FRICTION
		else:
			velocity_y = move_toward(velocity_y, 0, FRICTION)

		velocity_x = clamp(velocity_x, -SPEED_CAP, SPEED_CAP)
		velocity_y = clamp(velocity_y, -SPEED_CAP, SPEED_CAP)

		position.x += velocity_x
		position.y += velocity_y

	_clamp_to_screen()

func _clamp_to_screen():
	var screen_size = get_viewport_rect().size
	var shape = $CollisionShape2D.shape
	var margin: float = shape.radius if shape is CircleShape2D else 16.0
	position.x = clamp(position.x, margin, screen_size.x - margin)
	position.y = clamp(position.y, margin, screen_size.y - margin)

# ============================================================================
# 3. DEBUG
# ============================================================================

func _process(_delta):
	if Input.is_action_just_pressed("ui_home"):
		print("Player: --- DEBUG GRACZA ---")
		print("Player: Statek ID: ", PlayerSetup.ship_id)
		print("Player: Prędkość X/Y: ", velocity_x, "/", velocity_y)
		print("Player: Pancerz: ", armor, "/", max_armor)
