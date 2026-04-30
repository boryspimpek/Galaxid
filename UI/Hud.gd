extends CanvasLayer

@onready var power_bar: ProgressBar = $SidePanel/Margin/MainVBox/HBoxGuns/PowerBar
@onready var shield_bar: ProgressBar = $SidePanel/Margin/MainVBox/LowerSection/HBoxStatus/ShieldBar
@onready var armor_bar: ProgressBar = $SidePanel/Margin/MainVBox/LowerSection/HBoxStatus/ArmorBar

@onready var _lbl_weapon: Label = $SidePanel/Margin/MainVBox/HBoxGuns/ButtonList/T1
@onready var _lbl_level: Label  = $SidePanel/Margin/MainVBox/HBoxGuns/ButtonList/T6
@onready var _lbl_gen: Label    = $SidePanel/Margin/MainVBox/HBoxGuns/ButtonList/T3
@onready var _lbl_shield: Label = $SidePanel/Margin/MainVBox/HBoxGuns/ButtonList/T4

var _player: CharacterBody2D
var _shield_system: Node
var _weapon_system: Node

func _ready():
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		return
	_shield_system = _player.get_node_or_null("ShieldSystem")
	_weapon_system = _player.get_node_or_null("WeaponSystem")

	power_bar.max_value = _player.power_max
	armor_bar.max_value = _player.max_armor
	if _shield_system:
		shield_bar.max_value = _shield_system.shield_max

	_connect_buttons()
	_update_labels()

func _connect_buttons():
	var bl = $SidePanel/Margin/MainVBox/HBoxGuns/ButtonList
	bl.get_node("HBoxContainer/Btn1").pressed.connect(_on_weapon_prev)
	bl.get_node("HBoxContainer/Btn7").pressed.connect(_on_weapon_next)
	bl.get_node("HBoxContainer2/Btn1").pressed.connect(_on_level_prev)
	bl.get_node("HBoxContainer2/Btn7").pressed.connect(_on_level_next)
	bl.get_node("HBoxContainer4/Btn1").pressed.connect(_on_gen_prev)
	bl.get_node("HBoxContainer4/Btn7").pressed.connect(_on_gen_next)
	bl.get_node("HBoxContainer6/Btn1").pressed.connect(_on_shield_prev)
	bl.get_node("HBoxContainer6/Btn7").pressed.connect(_on_shield_next)

func _shorten(text: String) -> String:
	if text.length() <= 12:
		return text
	return text.left(11) + "…"

func _update_labels():
	var wp = DataManager.get_weapon_port_by_id(PlayerSetup.front_weapon_index)
	_lbl_weapon.text = _shorten(wp.get("name", "?"))
	_lbl_level.text = str(PlayerSetup.front_power_level)
	var gen = DataManager.get_generator_by_id(PlayerSetup.generator_id)
	_lbl_gen.text = _shorten(gen.get("name", "?"))
	var sh = DataManager.get_shield_by_id(PlayerSetup.shield_id)
	_lbl_shield.text = _shorten(sh.get("name", "?"))

func _reload_systems():
	if _weapon_system:
		_weapon_system.load_weapon_config()
	if _shield_system:
		_shield_system.reload()
		shield_bar.max_value = _shield_system.shield_max
	if _player:
		_player.reload_power_regeneration()
	_update_labels()

# --- Weapon 1 ---

func _on_weapon_prev():
	var max_idx = DataManager.get_weapon_ports().size() - 1
	PlayerSetup.front_weapon_index = wrapi(PlayerSetup.front_weapon_index - 1, 0, max_idx + 1)
	_reload_systems()

func _on_weapon_next():
	var max_idx = DataManager.get_weapon_ports().size() - 1
	PlayerSetup.front_weapon_index = wrapi(PlayerSetup.front_weapon_index + 1, 0, max_idx + 1)
	_reload_systems()

# --- Level ---

func _on_level_prev():
	PlayerSetup.front_power_level = wrapi(PlayerSetup.front_power_level - 1, 1, 12)
	_reload_systems()

func _on_level_next():
	PlayerSetup.front_power_level = wrapi(PlayerSetup.front_power_level + 1, 1, 12)
	_reload_systems()

# --- Generator ---

func _on_gen_prev():
	var max_idx = DataManager.get_generators().size() - 1
	PlayerSetup.generator_id = wrapi(PlayerSetup.generator_id - 1, 0, max_idx + 1)
	_reload_systems()

func _on_gen_next():
	var max_idx = DataManager.get_generators().size() - 1
	PlayerSetup.generator_id = wrapi(PlayerSetup.generator_id + 1, 0, max_idx + 1)
	_reload_systems()

# --- Shield ---

func _on_shield_prev():
	var max_idx = DataManager.get_shields().size() - 1
	PlayerSetup.shield_id = wrapi(PlayerSetup.shield_id - 1, 0, max_idx + 1)
	_reload_systems()

func _on_shield_next():
	var max_idx = DataManager.get_shields().size() - 1
	PlayerSetup.shield_id = wrapi(PlayerSetup.shield_id + 1, 0, max_idx + 1)
	_reload_systems()

func _process(_delta):
	if not _player:
		return
	power_bar.value = _player.power
	armor_bar.value = _player.armor
	if _shield_system:
		shield_bar.value = _shield_system.shield
