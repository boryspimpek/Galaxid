extends CanvasLayer

@onready var power_bar: ProgressBar = $SidePanel/Margin/MainVBox/HBoxGuns/PowerBar
@onready var shield_bar: ProgressBar = $SidePanel/Margin/MainVBox/LowerSection/HBoxStatus/ShieldBar
@onready var armor_bar: ProgressBar = $SidePanel/Margin/MainVBox/LowerSection/HBoxStatus/ArmorBar

var _player: CharacterBody2D
var _shield_system: Node

func _ready():
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		return
	_shield_system = _player.get_node_or_null("ShieldSystem")

	power_bar.max_value = _player.power_max
	armor_bar.max_value = _player.max_armor
	if _shield_system:
		shield_bar.max_value = _shield_system.shield_max

func _process(_delta):
	if not _player:
		return
	power_bar.value = _player.power
	armor_bar.value = _player.armor
	if _shield_system:
		shield_bar.value = _shield_system.shield
