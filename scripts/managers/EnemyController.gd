extends Node

# Klasa odpowiedzialna za globalne sterowanie wrogami

var level_manager: Node2D

func _init(p_level_manager: Node2D):
	level_manager = p_level_manager

func enemy_fire_power(event: Dictionary):
	var new_tur  = event.get("new_tur",  [-1, -1, -1])
	var new_freq = event.get("new_freq", [-1, -1, -1])
	var link_num = int(event.get("link_num", 0))

	for enemy in level_manager.get_tree().get_nodes_in_group("enemies"):
		if enemy.link_num != link_num:
			continue
		for i in range(3):
			if int(new_tur[i]) != -1:
				enemy.tur[i] = int(new_tur[i])
			if int(new_freq[i]) != -1:
				enemy.freq[i] = int(new_freq[i])
		enemy.eshotwait = [1.0, 1.0, 1.0]
		enemy.refresh_weapon_cache()

