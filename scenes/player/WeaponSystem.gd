extends Node

# ============================================================================
# WEAPON SYSTEM - Logika strzelania
# ============================================================================

# --- Referencje ---
var player: CharacterBody2D
var muzzle: Marker2D
var projectile_scene: PackedScene

# --- Dane broni ---
var weapon_data: Dictionary = {}
var current_weapon_index: int = 1
var power_level: int = 1

# --- Konfiguracja strzelania ---
var fire_cooldown: float = 0.1
var fire_timer: int = 0  # Zmienione na int (system klatkowy)
var is_firing: bool = false

# --- Stan strzelania (dla patterns) ---
var pattern_index: int = 0
var shot_repeat_count: int = 0

func _ready():
	player = get_parent()
	muzzle = player.get_node("Muzzle")
	
	# Załaduj scene projectile
	projectile_scene = load("res://scenes/projectile/projectile.tscn")
	
	# Załaduj konfigurację broni
	load_weapon_config()

func _physics_process(_delta):
	# Cooldown (system klatkowy, nie delta)
	if fire_timer > 0:
		fire_timer -= 1
	
	# Strzelanie jeśli wciśnięty przycisk
	if is_firing and fire_timer <= 0:
		shoot()

func load_weapon_config():
	current_weapon_index = PlayerSetup.front_weapon_index
	power_level = PlayerSetup.front_power_level
	
	var weapon_mode = PlayerSetup.front_weapon_mode
	
	# Krok 1: Pobierz indeks sposobu strzelania z weapon_ports.json
	var firing_index = DataManager.get_weapon_firing_index(current_weapon_index, weapon_mode, power_level)
	
	# Krok 2: Pobierz dane broni z weapon.json używając firing_index
	var weapon_id_str = str(firing_index).pad_zeros(4)
	weapon_data = DataManager.get_weapon_by_id(weapon_id_str)
	
	if weapon_data.is_empty():
		push_error("WeaponSystem: Nie znaleziono broni o ID: ", weapon_id_str, " (firing_index=", firing_index, ")")
	else:
		print("WeaponSystem: Załadowano broń - port_index=", current_weapon_index, " mode=", weapon_mode, " power=", power_level, " weapon_id=", weapon_id_str)

func set_firing(firing: bool):
	is_firing = firing

func shoot():
	if weapon_data.is_empty():
		return
	
	# Sprawdź drain (koszt energii)
	var drain = weapon_data.get("drain", 0)
	if player.power < drain:
		return
	
	# Odejmij drain
	player.power -= drain
	
	var patterns = weapon_data.get("patterns", [])
	if patterns.is_empty():
		return
	
	# Multi-shot - ilość pocisków na raz
	var multi = weapon_data.get("multi", 0)
	if multi == 0:
		multi = 1
	
	# Strzelaj multi-shot
	for i in range(multi):
		if i < patterns.size():
			var pattern = patterns[i]
			var attack = pattern.get("attack", 0)
			var sx = pattern.get("sx", 0)
			var sy = pattern.get("sy", 0)
			var bx = pattern.get("bx", 0)
			var by = pattern.get("by", 0)
			
			# Ignoruj puste wpisy (attack=0)
			if attack <= 0:
				continue
			
			# Stwórz projectile z offsetem bx/by
			create_projectile(attack, sx, sy, bx, by)
	
	# Ustaw cooldown z repeat (shotRepeat z JSON)
	# repeat to ilość klatek w 30 FPS, mnożymy x2 dla 60 FPS
	var repeat = weapon_data.get("shotRepeat", 0)
	fire_timer = repeat * 2

func create_projectile(damage: int, sx: int, sy: int, bx: int = 0, by: int = 0):
	if not projectile_scene:
		return
	
	var projectile = projectile_scene.instantiate()
	
	# Ustaw pozycję na muzzle + offset bx/by
	projectile.global_position = muzzle.global_position + Vector2(bx, -by)
	
	# Ustaw velocity (sx/sy to prędkość w Tyrianie)
	# sx to prędkość X, sy to prędkość Y (ujemne = w górę)
	var velocity = Vector2(float(sx), float(-sy))  # Odwracam Y bo w Godot Y w dół
	projectile.velocity = velocity
	
	# Ustaw damage (może być skalowane przez power level)
	var scaled_damage = damage * power_level
	projectile.damage = scaled_damage
	
	# Dodaj do sceny
	get_tree().current_scene.add_child(projectile)
	
	print("WeaponSystem: Strzał - damage=", scaled_damage, " velocity=", velocity, " offset=", Vector2(bx, -by))
