extends Node

# ============================================================================
# DAMAGE SYSTEM - Obsługa obrażeń i kolizji
# ============================================================================

# --- Referencje ---
var player: CharacterBody2D

func _ready():
	player = get_parent()

# TODO: Podłącz sygnały kolizji w Player.tscn (Area2D)

func take_damage(amount: int):
	# TODO: Zmniejsz armor gracza
	# TODO: Obsłuż śmierć
	pass
