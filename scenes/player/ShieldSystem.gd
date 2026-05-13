extends Node

const SHIELD_WAIT = 15.0

var player: CharacterBody2D

var shield: float = 0.0
var shield_max: float = 0.0
var shield_t: int = 0    # tpwr*20: koszt power za 1 punkt regeneracji
var _wait_timer: float = 0.0

func _ready():
	player = get_parent()
	load_shield_config()

func load_shield_config():
	var shield_data = DataManager.get_shield_by_id(PlayerSetup.shield_id)
	if shield_data:
		shield_t   = shield_data.generator_needed * 20
		shield     = float(shield_data.protection)
		shield_max = float(shield_data.protection * 2)
		print("ShieldSystem: shield=", shield, "/", shield_max, " shield_t=", shield_t, " (power/pkt)")
	else:
		push_warning("ShieldSystem: brak danych tarczy (shield_id=%d)" % PlayerSetup.shield_id)

func _physics_process(_delta): # Delta ignorowana
	# 1. Odliczanie klatkowe
	if _wait_timer > 0:
		_wait_timer -= 1 # Odejmujemy po prostu 1 klatkę
		
	# 2. Regeneracja
	if shield < shield_max and _wait_timer <= 0:
		if player.power >= shield_t:
			player.power -= shield_t
			shield += 1.0
			_wait_timer = SHIELD_WAIT # Resetujemy na 15 klatek

func reload():
	load_shield_config()

func take_shield_damage(amount: float):
	shield = max(shield - amount, 0.0)
