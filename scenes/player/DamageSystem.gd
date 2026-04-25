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
	# print("--- HIT  dmg=%d  shield=%.1f  armor=%d" % [amount, shield_system.shield if shield_system else 0.0, player.armor])
	if shield_system and shield_system.shield > 0 and shield_system.protection > 0:
		var points_needed = ceili(float(amount) / shield_system.protection)
		var points_consumed = min(points_needed, shield_system.shield)
		shield_system.take_shield_damage(points_consumed)
		var actually_absorbed = min(points_consumed * shield_system.protection, amount)
		amount -= actually_absorbed
		# print("    tarcza pochłonęła %.0f  (-%d pkt)  shield=%.1f" % [actually_absorbed, points_consumed, shield_system.shield])

	if amount > 0:
		player.armor -= amount
		# print("    przebicie do pancerza -%d  armor=%d" % [amount, player.armor])
		if player.armor <= 0:
			player.armor = 0
			_on_player_death()

func _on_player_death():
	print("Player: ŚMIERĆ")
