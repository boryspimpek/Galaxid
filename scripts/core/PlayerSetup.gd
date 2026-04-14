extends Node

var ship_id: int = 1
var generator_id: int = 1
var shield_id: int = 1

var front_weapon = {
	"id": 1,
	"level": 1
}

var rear_weapon = {
	"id": 1,
	"level": 1
}

# Ta funkcja pozwoli innym skryptom (jak player.gd) pobrać wszystko na raz w formie słownika
func get_setup_dict() -> Dictionary:
	return {
		"ship_id": ship_id,
		"generator_id": generator_id,
		"shield_id": shield_id,
		"front_weapon": front_weapon,
		"rear_weapon": rear_weapon
	}