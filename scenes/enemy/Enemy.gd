extends Area2D

# ---- Sygnały ----
signal projectile_spawned(projectile)

# ---- Statystyki ----
@export var armor: int = 1
@export var esize: int = 0
@export var enemy_id: int = 0
@export var event_type: int = 0
@export var link_num: int = 0
@export var enemy_slot: int = 0

# ---- Ruch ----
# velocity odpowiada exc/eyc z silnika Tyrian
@export var velocity: Vector2 = Vector2(0, 0)
@export var fixed_move_y: int = 0
@export var scroll_y: int = 2

# ---- Silnik wahadłowy (xcaccel / ycaccel) ----
@export var excc: int = 0
@export var eycc: int = 0
@export var xrev: int = 0
@export var yrev: int = 0

var exccw: int = 0
var eyccw: int = 0
var exccwmax: int = 0
var eyccwmax: int = 0
var exccadd: int = 1
var eyccadd: int = 1

# ---- Losowe przyspieszenie ----
@export var xaccel: int = 0
@export var yaccel: int = 0

# ---- System strzelania ----
@export var tur: Array = [0, 0, 0]   # ID broni [down, right, left]
@export var freq: Array = [0, 0, 0]  # Częstotliwość strzelania [down, right, left]
var projectile_scene: PackedScene    # Scena pocisku wroga
var sprites_folder: String = ""

var eshotwait: Array    = [0.0, 0.0, 0.0]  # Licznik cooldown (w klatkach Tyrian)
var eshotwaitmax: Array = [0.0, 0.0, 0.0]  # Maksymalny cooldown z freq
var eshotmultipos: Array = [0, 0, 0]       # Pozycja w cyklu patternów dla każdego kierunku

# ---- Granice usuwania (z GameConstants) ----
const BOUNDS_LEFT   = GameConstants.BOUNDS_LEFT
const BOUNDS_RIGHT  = GameConstants.BOUNDS_RIGHT
const BOUNDS_TOP    = GameConstants.BOUNDS_TOP
const BOUNDS_BOTTOM = GameConstants.BOUNDS_BOTTOM

# Referencje do węzłów
@onready var visual: Sprite2D = $Visual
@onready var debug_label: Label = $DebugLabel

func _ready():
	add_to_group("enemies")
	# Warstwa 2 = wróg; maska 4 = pociski gracza, maska 1 = ciało gracza
	collision_layer = 2
	collision_mask  = 5
	body_entered.connect(_on_body_entered)

	# Konwersja xrev/yrev — zawsze przy spawnie, niezależnie od excc/eycc (jak w Tyrianie)
	if xrev == 0:    xrev = 100
	elif xrev == -99: xrev = 0

	if yrev == 0:    yrev = 100
	elif yrev == -99: yrev = 0

	# Inicjalizacja silnika wahadłowego X
	if excc != 0:
		exccw    = abs(excc)
		exccwmax = exccw
		exccadd  = 1 if excc > 0 else -1

	# Inicjalizacja silnika wahadłowego Y
	if eycc != 0:
		eyccw    = abs(eycc)
		eyccwmax = eyccw
		eyccadd  = 1 if eycc > 0 else -1

	# Inicjalizacja systemu strzelania
	for i in range(3):
		var weapon_id = tur[i]
		eshotwaitmax[i] = float(freq[i])
		if weapon_id == 252:
			eshotwait[i] = 1.0  # specjalna broń strzela od razu
		elif weapon_id != 0:
			eshotwait[i] = eshotwaitmax[i]  # normalna broń - użyj freq
		else:
			eshotwait[i] = 255.0  # brak broni - duży cooldown

	
	var texture = visual.texture
	# Fallback przez DataManager wyłączony — tekstura powinna pochodzić ze sceny Enemy_XXX.tscn
	# if not texture:
	# 	texture = DataManager.get_enemy_texture(enemy_id, sprites_folder)
	if texture:
		visual.texture = texture
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		visual.scale = GameConstants.ENEMY_SPRITE_SIZE / texture.get_size()
	else:
		print("Enemy %d: brak tekstury w scenie" % enemy_id)

	if debug_label:
		debug_label.text = "ID:%d" % enemy_id
		debug_label.visible = false
	
func _process_shooting(_delta: float):
	for i in range(3):
		if tur[i] == 0 or freq[i] == 0:
			continue

		eshotwait[i] -= 1
		if eshotwait[i] <= 0.0:
			_fire_projectile(i)
			eshotwait[i] += eshotwaitmax[i]

func _fire_projectile(direction_index: int):
	if not projectile_scene:
		print("ERROR: projectile_scene pusty")
		return

	var weapon_id = int(tur[direction_index])
	# print("Strzał! weapon_id=", weapon_id, " direction=", direction_index)

	var weapon_data = DataManager.get_weapon_by_id(weapon_id)

	if weapon_data.is_empty():
		print("ERROR: Nie znaleziono broni o ID=", weapon_id)
		return

	var patterns = weapon_data.get("patterns", [])
	if patterns.is_empty():
		return

	var weapon_multi = int(weapon_data.get("multi", 1))
	var weapon_max   = int(weapon_data.get("max", 1))
	var aim          = int(weapon_data.get("aim", 0))

	# Szkielet dla specjalnych wartości tur (251-255)
	match weapon_id:
		251:
			# Suck-O-Magnet - TODO: przyciąga statek gracza
			pass
		252:
			# Savara Boss DualMissile - już obsługiwane
			pass
		253:
			# Left ShortRange Magnet - TODO: odpycha gracza w lewo (krótki zasięg)
			pass
		254:
			# Right ShortRange Magnet - TODO: odpycha gracza w prawo (krótki zasięg)
			pass
		255:
			# Magneto RePulse - TODO: odpycha gracza (długi zasięg) + filtr wizualny
			pass
		_:
			# Normalna broń - kontynuuj z standardową logiką
			pass

	for _i in range(weapon_multi):
		var temp_pos = eshotmultipos[direction_index]
		if temp_pos >= patterns.size():
			temp_pos = 0  # Fallback jeśli patterny są za małe

		var pattern = patterns[temp_pos]
		var attack  = pattern.get("attack", 1)
		var sx      = pattern.get("sx", 0)
		var sy      = pattern.get("sy", 0)
		var bx      = pattern.get("bx", 0)
		var by      = pattern.get("by", 0)
		var sg      = pattern.get("sg", 0)

		# print("DEBUG: direction_index=", direction_index, " temp_pos=", temp_pos, " sx=", sx, " sy=", sy)

		# Oblicz prędkość w zależności od kierunku (zgodnie z kodem Tyrian)
		# direction_index: 0 = down, 1 = right, 2 = left
		var projectile_velocity: Vector2
		
		if aim > 0:
			# Logika aim: celowanie w gracza
			var player = get_parent().get_node_or_null("Player")
			if player:
				var target_pos = player.global_position
				var aim_x = target_pos.x - global_position.x
				var aim_y = target_pos.y - global_position.y
				
				# Normalizacja przez maxMagAim (największą składową)
				var max_mag_aim = max(abs(aim_x), abs(aim_y))
				if max_mag_aim > 0:
					aim_x = aim_x / max_mag_aim
					aim_y = aim_y / max_mag_aim
				
				# Mnożenie przez aim i zaokrąglenie
				var sxm = round(aim_x * float(aim))
				var sym = round(aim_y * float(aim))
				
				projectile_velocity = Vector2(sxm, sym)
			else:
				# Fallback jeśli gracz nie istnieje
				projectile_velocity = Vector2(float(sx), float(sy))
		else:
			# Standardowa logika sx/sy
			match direction_index:
				0:  # down
					projectile_velocity = Vector2(float(sx), float(sy))
				1:  # right: obrót 90° w prawo
					projectile_velocity = Vector2(float(sy), float(-sx))
				2:  # left: obrót 90° w lewo
					projectile_velocity = Vector2(float(-sy), float(-sx))
				_:
					projectile_velocity = Vector2(float(sx), float(sy))

		# print("DEBUG: final velocity=", projectile_velocity)

		# Utwórz pocisk
		var projectile = projectile_scene.instantiate()
		projectile.velocity = projectile_velocity
		projectile.damage = attack
		projectile.sprite_id = sg
		projectile.tx = int(weapon_data.get("tx", 0))
		projectile.ty = int(weapon_data.get("ty", 0))
		projectile.acceleration = int(weapon_data.get("acceleration", 0))
		projectile.accelerationx = int(weapon_data.get("accelerationx", 0))
		projectile.duration = float(pattern.get("del", 255))

		# Oblicz pozycję startową z offsetem bx/by
		var offset_x = float(bx)
		var offset_y = float(by)
		projectile.global_position = global_position + Vector2(offset_x, offset_y)

		# Emituj sygnał do spawnu pocisku (LevelManager doda go do sceny)
		projectile_spawned.emit(projectile)
		# print("Pocisk utworzony na pozycji: ", projectile.global_position, " velocity: ", projectile.velocity)

		# Inkrementuj po wyborze i spawn pocisku, zawijaj po weapon_max
		eshotmultipos[direction_index] = (eshotmultipos[direction_index] + 1) % weapon_max

func _process(_delta):
	velocity.x += float(xaccel)
	velocity.y += float(yaccel)

	# --- 1. Silnik wahadłowy X (Zsynchronizowany) ---
	if excc != 0:
		exccw -= 1
		if exccw <= 0:
			if velocity.x == xrev:          # sprawdź PRZED dodaniem
				excc = -excc
				xrev = -xrev
				exccadd = -exccadd
				# exccw NIE jest resetowane tutaj
			else:
				velocity.x += exccadd
				exccw += exccwmax            # reset tylko tutaj
				if velocity.x == xrev:      # sprawdź PO dodaniu
					excc = -excc
					xrev = -xrev
					exccadd = -exccadd

	# --- 2. Silnik wahadłowy Y (Zsynchronizowany) ---
	if eycc != 0:
		eyccw -= 1
		if eyccw <= 0:
			if velocity.y == yrev:          # sprawdź PRZED dodaniem
				eycc = -eycc
				yrev = -yrev
				eyccadd = -eyccadd
				# eyccw NIE jest resetowane tutaj
			else:
				velocity.y += eyccadd
				eyccw += eyccwmax            # reset tylko tutaj
				if velocity.y == yrev:      # sprawdź PO dodaniu
					eycc = -eycc
					yrev = -yrev
					eyccadd = -eyccadd
			
	# --- 3. Przeliczenie na px/s Godot i zastosowanie ruchu ---
	var move_x = velocity.x
	var move_y = (float(fixed_move_y) + velocity.y + float(scroll_y))

	position.x += move_x
	position.y += move_y

	# --- 4. System strzelania ---
	_process_shooting(_delta)

	# --- 5. Usuń poza ekranem (jeden warunek — poprawka podwójnego queue_free) ---
	if position.x < BOUNDS_LEFT  or position.x > BOUNDS_RIGHT \
	or position.y < BOUNDS_TOP   or position.y > BOUNDS_BOTTOM:
		queue_free()
	# if enemy_id == 5:
	# 	print("F:", Engine.get_frames_drawn(), " vx:", velocity.x, " vy:", velocity.y, " x:", position.x, " y:", position.y, " exccw:", exccw, " excc:", excc)

# ============================================================================
# SYSTEM OBRAŻEŃ
# ============================================================================

func take_damage(amount: int):
	armor -= amount
	if armor <= 0:
		die()
	else:
		SoundManager.play_sound(3)  # S_ENEMY_HIT

func die():
	if esize == 1:
		SoundManager.play_sound(9)  # S_EXPLOSION_9 - duży wróg
	else:
		SoundManager.play_sound(8)  # S_EXPLOSION_8 - mały wróg
	queue_free()

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		var ds = body.get_node_or_null("DamageSystem")
		if ds:
			ds.take_damage(armor)
		die()
