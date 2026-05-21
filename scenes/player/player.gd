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
var _clamp_margin := Vector4.ZERO  # left, top, right, bottom

# --- Systemy (child nodes) ---
@onready var weapon_system: Node = $WeaponSystem
@onready var damage_system: Node = $DamageSystem
@onready var shield_system: Node = $ShieldSystem
@onready var ship_model: Node3D = $SubViewport/PlayerModel

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
	_compute_clamp_margins()
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
	var prev_x: float = position.x
	position = get_global_mouse_position()
	_clamp_to_screen()
	weapon_system.set_firing(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	_update_tilt(position.x - prev_x, delta)

func _update_tilt(dx: float, delta: float) -> void:
	var target: float = clampf(-dx * 0.04, -0.6, 0.6)
	ship_model.rotation.z = lerpf(ship_model.rotation.z, target, delta * 8.0)

const PLAY_AREA := Vector2(1080, 1920)

func _compute_clamp_margins():
	var points: PackedVector2Array = $CollisionPolygon2D.polygon
	var min_x := points[0].x; var max_x := points[0].x
	var min_y := points[0].y; var max_y := points[0].y
	for p in points:
		min_x = min(min_x, p.x); max_x = max(max_x, p.x)
		min_y = min(min_y, p.y); max_y = max(max_y, p.y)
	_clamp_margin = Vector4(-min_x, -min_y, max_x, max_y)

func _clamp_to_screen():
	position.x = clamp(position.x, _clamp_margin.x, PLAY_AREA.x - _clamp_margin.z)
	position.y = clamp(position.y, _clamp_margin.y, PLAY_AREA.y - _clamp_margin.w)

# ============================================================================
# 3. DEBUG
# ============================================================================

func _process(_delta):
	if Input.is_action_just_pressed("ui_home"):
		print("Player: --- DEBUG GRACZA ---")
		print("Player: Statek ID: ", PlayerSetup.ship_id)
		print("Player: Pozycja: ", position)
		print("Player: Pancerz: ", armor, "/", max_armor)
