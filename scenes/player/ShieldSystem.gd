extends Node

# ============================================================================
# SHIELD SYSTEM - Obsługa tarczy
# ============================================================================

var player: CharacterBody2D

var shield: int = 0
var max_shield: int = 0
var shield_regen_rate: float = 0.0  # punkty na sekundę

func _ready():
	player = get_parent()
	var shield_data = DataManager.get_shield_by_id(PlayerSetup.shield_id)
	if not shield_data.is_empty():
		var stats = shield_data.get("stats", {})
		max_shield      = stats.get("capacity", 0)
		shield_regen_rate = float(stats.get("regen_rate", 0.0))
		shield          = max_shield
		print("ShieldSystem: tarcza=", shield, " regen=", shield_regen_rate, "/s")
	else:
		print("ShieldSystem: brak danych tarczy (shield_id=", PlayerSetup.shield_id, ")")

func _physics_process(delta):
	if shield < max_shield:
		shield = min(shield + shield_regen_rate * delta, max_shield)

func take_shield_damage(amount: int):
	shield = max(shield - amount, 0)
