extends Control

# ============================================================================
# PLAYER CONFIG UI - Interfejs do zmiany parametrów PlayerSetup
# ============================================================================

# Referencje do SpinBox
@onready var ship_id_spin = $Background/VBoxContainer/ShipId
@onready var generator_id_spin = $Background/VBoxContainer/GeneratorId
@onready var front_weapon_index_spin = $Background/VBoxContainer/FrontWeaponIndex
@onready var front_weapon_mode_spin = $Background/VBoxContainer/FrontWeaponMode
@onready var front_power_level_spin = $Background/VBoxContainer/FrontPowerLevel
@onready var rear_weapon_index_spin = $Background/VBoxContainer/RearWeaponIndex
@onready var rear_weapon_mode_spin = $Background/VBoxContainer/RearWeaponMode
@onready var rear_power_level_spin = $Background/VBoxContainer/RearPowerLevel

# Referencje do etykiet z nazwami
@onready var ship_name_label: Label = $Background/VBoxContainer/ShipNameLabel
@onready var generator_name_label: Label = $Background/VBoxContainer/GeneratorNameLabel
@onready var front_weapon_name_label: Label = $Background/VBoxContainer/FrontWeaponNameLabel
@onready var rear_weapon_name_label: Label = $Background/VBoxContainer/RearWeaponNameLabel

func _ready():
	load_values_from_setup()
	update_names()

	# Podłącz sygnały - Callable z argumentem nazwy parametru
	ship_id_spin.value_changed.connect(_on_ship_id_changed)
	generator_id_spin.value_changed.connect(_on_generator_id_changed)
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

func reload_ship_data():
	# Znajdź gracza w scenie i przeładuj dane statku
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player:
		player.load_ship_data()
		player.apply_ship_stats()
		print("PlayerConfigUI: Przeładowano dane statku")


func load_values_from_setup():
	ship_id_spin.value = PlayerSetup.ship_id
	generator_id_spin.value = PlayerSetup.generator_id
	front_weapon_index_spin.value = PlayerSetup.front_weapon_index
	front_weapon_mode_spin.value = PlayerSetup.front_weapon_mode
	front_power_level_spin.value = PlayerSetup.front_power_level
	rear_weapon_index_spin.value = PlayerSetup.rear_weapon_index
	rear_weapon_mode_spin.value = PlayerSetup.rear_weapon_mode
	rear_power_level_spin.value = PlayerSetup.rear_power_level

func update_names():
	# Nazwa statku
	var ship = DataManager.get_ship_by_id(PlayerSetup.ship_id)
	if not ship.is_empty():
		ship_name_label.text = ship.get("name", "Unknown Ship")
	else:
		ship_name_label.text = "Unknown Ship"
	
	# Nazwa generatora
	var generator = DataManager.get_generator_by_id(PlayerSetup.generator_id)
	if not generator.is_empty():
		generator_name_label.text = generator.get("name", "Unknown Generator")
	else:
		generator_name_label.text = "Unknown Generator"
	
	# Nazwa przedniej broni
	var front_weapon = DataManager.get_weapon_port_by_id(PlayerSetup.front_weapon_index)
	if not front_weapon.is_empty():
		front_weapon_name_label.text = front_weapon.get("name", "Unknown Weapon")
	else:
		front_weapon_name_label.text = "Unknown Weapon"
	
	# Nazwa tylnej broni
	var rear_weapon = DataManager.get_weapon_port_by_id(PlayerSetup.rear_weapon_index)
	if not rear_weapon.is_empty():
		rear_weapon_name_label.text = rear_weapon.get("name", "Unknown Weapon")
	else:
		rear_weapon_name_label.text = "Unknown Weapon"

func _on_ship_id_changed(value: float):
	PlayerSetup.ship_id = int(value)
	print("PlayerConfigUI: Zmieniono ship_id = ", int(value))
	ship_id_spin.release_focus()
	reload_ship_data()
	update_names()

func _on_generator_id_changed(value: float):
	PlayerSetup.generator_id = int(value)
	print("PlayerConfigUI: Zmieniono generator_id = ", int(value))
	generator_id_spin.release_focus()
	reload_power_regeneration()
	update_names()

func reload_power_regeneration():
	# Znajdź gracza w scenie i przeładuj regenerację energii
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player:
		player.reload_power_regeneration()
		print("PlayerConfigUI: Przeładowano regenerację energii")

func _on_front_weapon_index_changed(value: float):
	PlayerSetup.front_weapon_index = int(value)
	print("PlayerConfigUI: Zmieniono front_weapon_index = ", int(value))
	front_weapon_index_spin.release_focus()
	reload_weapon_config()
	update_names()

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
	update_names()

func _on_rear_weapon_mode_changed(value: float):
	PlayerSetup.rear_weapon_mode = int(value)
	print("PlayerConfigUI: Zmieniono rear_weapon_mode = ", int(value))
	rear_weapon_mode_spin.release_focus()

func _on_rear_power_level_changed(value: float):
	PlayerSetup.rear_power_level = int(value)
	print("PlayerConfigUI: Zmieniono rear_power_level = ", int(value))
	rear_power_level_spin.release_focus()
