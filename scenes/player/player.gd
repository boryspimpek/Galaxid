extends CharacterBody2D

# --- Loadout (konfiguracja w inspektorze) ---
@export var ship_id: int = 1
@export var front_weapon_index: int = 1
@export var front_weapon_mode: int = 1
@export var front_power_level: int = 1
@export var generator_id: int = 1
@export var shield_id: int = 1

# --- Zmienne dynamiczne (zmieniają się w locie) ---
var armor: int = 0
var max_armor: int = 0

# --- System energii (Power) ---
var power: float = 900.0
var power_max: float = 900.0
var power_add: float = 0.0

var ship_data: ShipData = null

# --- Systemy (child nodes) ---
@onready var weapon_system: Node = $WeaponSystem
@onready var damage_system: Node = $DamageSystem
@onready var shield_system: Node = $ShieldSystem

# ============================================================================
# 1. INICJALIZACJA (Kolejność ma znaczenie!)
# ============================================================================

func _enter_tree():
	PlayerSetup.ship_id             = ship_id
	PlayerSetup.front_weapon_index  = front_weapon_index
	PlayerSetup.front_weapon_mode   = front_weapon_mode
	PlayerSetup.front_power_level   = front_power_level
	PlayerSetup.generator_id        = generator_id
	PlayerSetup.shield_id           = shield_id

func _ready():
	add_to_group("player")
	collision_layer = 1
	collision_mask  = 0
	load_ship_data()
	apply_ship_stats()
	init_power_regeneration()
	
func load_ship_data():
	var s_id = PlayerSetup.ship_id
	ship_data = DataManager.get_ship_by_id(s_id)
	if ship_data:
		print("Player: Statek załadowany: ", ship_data.ship_name)
	else:
		push_error("Player: BŁĄD: Nie znaleziono danych dla statku o ID: " + str(s_id))

func apply_ship_stats():
	armor = ship_data.armor if ship_data else 10
	max_armor = armor
	print("Player: Ship → armor=", armor)

func init_power_regeneration():
	var generator_power = DataManager.get_generator_power(PlayerSetup.generator_id)
	power_add = generator_power
	print("Player: Generator ID=", PlayerSetup.generator_id, " power=", generator_power, " → power_add=", power_add, " (energia/klatkę)")

func reload_power_regeneration():
	var generator_power = DataManager.get_generator_power(PlayerSetup.generator_id)
	power_add = generator_power
	print("Player: Przeładowano regenerację energii → power_add=", power_add)

# ============================================================================
# 2. RUCH
# ============================================================================

func _physics_process(delta: float):
	power = min(power_max, power + power_add * delta)
	position = get_global_mouse_position()
	_clamp_to_screen()
	weapon_system.set_firing(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

const PLAY_AREA := Vector2(1080, 1920)

func _clamp_to_screen():
	var margin: float = $CollisionShape2D.shape.radius
	position.x = clamp(position.x, margin, PLAY_AREA.x - margin)
	position.y = clamp(position.y, margin, PLAY_AREA.y - margin)

# ============================================================================
# 3. DEBUG
# ============================================================================

func _process(_delta):
	if Input.is_action_just_pressed("ui_home"):
		print("Player: --- DEBUG GRACZA ---")
		print("Player: Statek ID: ", PlayerSetup.ship_id)
		print("Player: Pozycja: ", position)
		print("Player: Pancerz: ", armor, "/", max_armor)
