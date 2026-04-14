extends Node

# ============================================================================
# SHIELD SYSTEM - Obsługa tarczy
# ============================================================================

# --- Referencje ---
var player: CharacterBody2D

# --- Statystyki tarczy ---
var shield: int = 0
var max_shield: int = 0
var shield_regen_rate: float = 1.0  # punkty na sekundę

func _ready():
	player = get_parent()
	# TODO: Załaduj shield_data z DataManager (PlayerSetup.shield_id)

func _physics_process(delta):
	# Regeneracja tarczy
	if shield < max_shield:
		shield = min(shield + shield_regen_rate * delta, max_shield)

func take_shield_damage(amount: int):
	shield = max(shield - amount, 0)
