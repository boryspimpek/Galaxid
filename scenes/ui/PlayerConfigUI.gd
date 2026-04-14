extends Control

# ============================================================================
# PLAYER CONFIG UI - Interfejs do zmiany parametrów PlayerSetup
# ============================================================================

# Referencje do SpinBox
@onready var ship_id_spin = $VBoxContainer/ShipId
@onready var front_weapon_index_spin = $VBoxContainer/FrontWeaponIndex
@onready var front_weapon_mode_spin = $VBoxContainer/FrontWeaponMode
@onready var front_power_level_spin = $VBoxContainer/FrontPowerLevel
@onready var rear_weapon_index_spin = $VBoxContainer/RearWeaponIndex
@onready var rear_weapon_mode_spin = $VBoxContainer/RearWeaponMode
@onready var rear_power_level_spin = $VBoxContainer/RearPowerLevel

func _ready():
	load_values_from_setup()

	# Podłącz sygnały - Callable z argumentem nazwy parametru
	ship_id_spin.value_changed.connect(_on_ship_id_changed)
	front_weapon_index_spin.value_changed.connect(_on_front_weapon_index_changed)
	front_weapon_mode_spin.value_changed.connect(_on_front_weapon_mode_changed)
	front_power_level_spin.value_changed.connect(_on_front_power_level_changed)
	rear_weapon_index_spin.value_changed.connect(_on_rear_weapon_index_changed)
	rear_weapon_mode_spin.value_changed.connect(_on_rear_weapon_mode_changed)
	rear_power_level_spin.value_changed.connect(_on_rear_power_level_changed)

func reload_weapon_config():
	# Znajdź gracza w scenie i przeładuj konfigurację broni
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and player.has_node("WeaponSystem"):
		var weapon_system = player.get_node("WeaponSystem")
		weapon_system.load_weapon_config()
		print("PlayerConfigUI: Przeładowano konfigurację broni")

func load_values_from_setup():
	ship_id_spin.value = PlayerSetup.ship_id
	front_weapon_index_spin.value = PlayerSetup.front_weapon_index
	front_weapon_mode_spin.value = PlayerSetup.front_weapon_mode
	front_power_level_spin.value = PlayerSetup.front_power_level
	rear_weapon_index_spin.value = PlayerSetup.rear_weapon_index
	rear_weapon_mode_spin.value = PlayerSetup.rear_weapon_mode
	rear_power_level_spin.value = PlayerSetup.rear_power_level

func _on_ship_id_changed(value: float):
	PlayerSetup.ship_id = int(value)
	print("PlayerConfigUI: Zmieniono ship_id = ", int(value))
	ship_id_spin.release_focus()

func _on_front_weapon_index_changed(value: float):
	PlayerSetup.front_weapon_index = int(value)
	print("PlayerConfigUI: Zmieniono front_weapon_index = ", int(value))
	front_weapon_index_spin.release_focus()
	reload_weapon_config()

func _on_front_weapon_mode_changed(value: float):
	PlayerSetup.front_weapon_mode = int(value)
	print("PlayerConfigUI: Zmieniono front_weapon_mode = ", int(value))
	front_weapon_mode_spin.release_focus()
	reload_weapon_config()

func _on_front_power_level_changed(value: float):
	PlayerSetup.front_power_level = int(value)
	print("PlayerConfigUI: Zmieniono front_power_level = ", int(value))
	front_power_level_spin.release_focus()
	reload_weapon_config()

func _on_rear_weapon_index_changed(value: float):
	PlayerSetup.rear_weapon_index = int(value)
	print("PlayerConfigUI: Zmieniono rear_weapon_index = ", int(value))
	rear_weapon_index_spin.release_focus()

func _on_rear_weapon_mode_changed(value: float):
	PlayerSetup.rear_weapon_mode = int(value)
	print("PlayerConfigUI: Zmieniono rear_weapon_mode = ", int(value))
	rear_weapon_mode_spin.release_focus()

func _on_rear_power_level_changed(value: float):
	PlayerSetup.rear_power_level = int(value)
	print("PlayerConfigUI: Zmieniono rear_power_level = ", int(value))
	rear_power_level_spin.release_focus()
