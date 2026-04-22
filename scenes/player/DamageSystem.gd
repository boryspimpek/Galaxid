extends Node

# ============================================================================
# DAMAGE SYSTEM - Obsługa obrażeń i kolizji
# ============================================================================

var player: CharacterBody2D
var shield_system: Node

func _ready():
	player = get_parent()
	shield_system = player.get_node("ShieldSystem")

func take_damage(amount: int):
	if shield_system and shield_system.shield > 0:
		var absorbed = min(amount, shield_system.shield)
		shield_system.take_shield_damage(absorbed)
		amount -= absorbed

	if amount > 0:
		player.armor -= amount
		if player.armor <= 0:
			player.armor = 0
			_on_player_death()

func _on_player_death():
	print("Player: ŚMIERĆ")
