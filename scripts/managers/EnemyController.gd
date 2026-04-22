extends Node

# Klasa odpowiedzialna za globalne sterowanie wrogami

var level_manager: Node2D
var enemies_active: bool = false

func _init(p_level_manager: Node2D):
	level_manager = p_level_manager

func set_enemies_active(p_active: bool):
	enemies_active = p_active

func disable_random_spawn(_event: Dictionary):
	enemies_active = false
	print("EnemyController: Random spawn wyłączony")

func enable_random_spawn(_event: Dictionary):
	enemies_active = true
	print("EnemyController: Random spawn włączony")

func enemy_global_accel(event: Dictionary):
	var new_excc  = event.get("new_excc",  -99)
	var new_eycc  = event.get("new_eycc",  -99)
	var link_num  = event.get("link_num",  0)

	# print("EnemyController: enemy_global_accel", " link_num: ", link_num)

	for child in level_manager.get_children():
		if not "enemy_id" in child:
			continue
		if link_num != 0 and child.link_num != link_num:
			continue

		if new_excc != -99:
			child.excc    = new_excc
			child.exccwmax = abs(new_excc) 
			child.exccw = abs(new_excc)
			child.exccadd = 1 if new_excc > 0 else -1

		if new_eycc != -99:
			child.eycc    = new_eycc
			child.eyccwmax = abs(new_eycc)
			child.eyccw = abs(new_eycc)
			child.eyccadd = 1 if new_eycc > 0 else -1

func enemy_global_accelrev(event: Dictionary):
	var new_exrev = event.get("new_exrev", -99)
	var new_eyrev = event.get("new_eyrev", -99)
	var link_num  = event.get("link_num",  0)

	for child in level_manager.get_children():
		if not "enemy_id" in child:
			continue
		if link_num != 0 and child.link_num != link_num:
			continue

		if new_exrev != -99:
			child.xrev = new_exrev
		if new_eyrev != -99:
			child.yrev = new_eyrev

func enemy_global_move(event: Dictionary):
	var new_exc        = event.get("new_exc",         -99)
	var new_eyc        = event.get("new_eyc",         -99)
	var new_fixed_move_y = event.get("new_fixed_move_y", 0)
	var scope_selector = event.get("scope_selector",  0)
	var link_num       = event.get("link_num",        0)

	for child in level_manager.get_children():
		if not "enemy_id" in child:
			continue

		var in_range = false
		match scope_selector:
			0:   in_range = true
			1:   in_range = (child.enemy_slot >= 25 && child.enemy_slot < 50)
			2:   in_range = (child.enemy_slot < 25)
			3:   in_range = (child.enemy_slot >= 50 && child.enemy_slot < 75)
			99:  in_range = true
			_:   in_range = true

		if not in_range:
			continue

		if scope_selector == 0 or scope_selector >= 80:
			if link_num != 0 and child.link_num != link_num:
				continue

		if new_exc != -99:
			child.velocity.x = float(new_exc)
		if new_eyc != -99:
			child.velocity.y = float(new_eyc)

		if new_fixed_move_y == -99:
			child.fixed_move_y = 0
		elif new_fixed_move_y != 0:
			child.fixed_move_y = new_fixed_move_y
