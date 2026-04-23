extends Node

const TYRIAN_FPS  = GameConstants.TYRIAN_FPS
const SHIELD_WAIT = 15.0 / TYRIAN_FPS  # 0.5s między każdym punktem regeneracji

var player: CharacterBody2D

var shield: float = 0.0
var shield_max: float = 0.0
var protection: int = 0  # mpwr: pojemność (shield=mpwr, shield_max=mpwr*2)
var shield_t: int = 0    # tpwr*20: koszt power za 1 punkt regeneracji
var _wait_timer: float = 0.0

func _ready():
	player = get_parent()
	load_shield_config()

func load_shield_config():
	var shield_data = DataManager.get_shield_by_id(PlayerSetup.shield_id)
	if not shield_data.is_empty():
		protection = shield_data.get("protection", 0)        # mpwr
		var tpwr   = shield_data.get("generator_needed", 0)  # tpwr
		shield_t   = tpwr * 20
		shield     = float(protection)
		shield_max = float(protection * 2)
		print("ShieldSystem: shield=", shield, "/", shield_max, " shield_t=", shield_t, " (power/pkt)")
	else:
		print("ShieldSystem: brak danych tarczy (shield_id=", PlayerSetup.shield_id, ")")

func _physics_process(delta):
	if _wait_timer > 0.0:
		_wait_timer -= delta

	# Regeneruj tylko jeśli tarcza wyposażona, niepełna i minął cooldown
	if protection > 0 and shield < shield_max and _wait_timer <= 0.0:
		if player.power >= shield_t:
			player.power -= shield_t
			shield       += 1.0
			_wait_timer   = SHIELD_WAIT

func reload():
	load_shield_config()

func take_shield_damage(amount: float):
	shield = max(shield - amount, 0.0)
