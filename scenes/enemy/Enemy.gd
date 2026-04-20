extends Node2D

# ---- Sygnały ----
signal projectile_spawned(projectile)

# ---- Stałe przeliczeniowe (z GameConstants) ----
const TYRIAN_FPS = GameConstants.TYRIAN_FPS
const SCALE_X    = GameConstants.SCALE_X
const SCALE_Y    = GameConstants.SCALE_Y

# ---- Statystyki ----
@export var armor: int = 1
@export var esize: int = 0
@export var enemy_id: int = 0
@export var event_type: int = 0
@export var link_num: int = 0
@export var enemy_slot: int = 0

# ---- Ruch (surowe jednostki Tyrian: px/klatkę np. @ 15 FPS) ----
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

# Runtime zmienne strzelania
# POPRAWKA 1: eshotwait jako float — dekrementowany przez delta * TYRIAN_FPS,
# dzięki czemu cooldown jest zsynchronizowany z tempem gry (TYRIAN_FPS).
var eshotwait: Array    = [0.0, 0.0, 0.0]  # Licznik cooldown (w klatkach Tyrian)
var eshotwaitmax: Array = [0.0, 0.0, 0.0]  # Maksymalny cooldown z freq
# POPRAWKA 2: eshotmultipos zaczyna od 0 (0-indexed), inkrementowany PO wyborze patternu.
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
	# Inicjalizacja silnika wahadłowego X
	if excc != 0:
		exccw    = abs(excc)
		exccwmax = exccw
		exccadd  = 1 if excc > 0 else -1
		if xrev == 0:
			xrev = 100

	# Inicjalizacja silnika wahadłowego Y
	if eycc != 0:
		eyccw    = abs(eycc)
		eyccwmax = eyccw
		eyccadd  = 1 if eycc > 0 else -1
		if yrev == 0:
			yrev = 100

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

	# Ustaw kolor na podstawie enemy_id
	var colors = [
		Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW,
		Color.CYAN, Color.MAGENTA, Color.ORANGE, Color.PURPLE
	]
	
	# Ustaw skalę sprite'a na podstawie esize
	# esize 0: 14x12px Tyrian -> skalowane przez SCALE_X/SCALE_Y
	# esize 1: 24x28px Tyrian -> skalowane przez SCALE_X/SCALE_Y
	var base_width: float
	var base_height: float
	if esize == 0:
		base_width  = 14.0
		base_height = 12.0
	else:
		base_width  = 24.0
		base_height = 28.0
	
	# Skala zostanie obliczona po załadowaniu tekstury, aby dopasować do rozmiaru bazowego
	
	# Próba załadowania grafiki wroga
	var enemy_id_str = "%03d" % enemy_id
	var texture_path = ""
	var texture: Texture2D = null
	
	# Użyj DirAccess do znalezienia pliku
	var dir = DirAccess.open("res://data/enemy_pic")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png") and not file_name.ends_with(".import"):
				# Sprawdź czy pasuje do wzorca enemy_XXX_bankYY_f00.png
				var regex = RegEx.new()
				regex.compile("^enemy_%s_bank\\d+_f00\\.png$" % enemy_id_str)
				var result = regex.search(file_name)
				if result:
					texture_path = "res://data/enemy_pic/" + file_name
					break
			file_name = dir.get_next()
		dir.list_dir_end()
	
	if texture_path != "":
		texture = load(texture_path)
		print("Enemy: enemy_id=", enemy_id, " found file: ", texture_path, " load result: ", texture != null)
	else:
		print("Enemy: enemy_id=", enemy_id, " no matching file found")
		
	if texture and texture is Texture2D:
		visual.texture = texture
		# Oblicz skalę aby tekstura miała odpowiedni rozmiar
		var tex_width = texture.get_width()
		var tex_height = texture.get_height()
		var scale_x = (base_width * SCALE_X) / tex_width
		var scale_y = (base_height * SCALE_Y) / tex_height
		visual.scale = Vector2(scale_x, scale_y)
		print("Enemy: Texture set successfully for enemy_", enemy_id_str, " scale: ", visual.scale)
	else:
		# Fallback: użyj ColorRect jako kolorowany kwadrat
		# Sprite2D bez tekstury nie wyświetla nic, więc musimy stworzyć fallback
		visual.texture = null
		# Użyj modulate zamiast color dla Sprite2D
		visual.modulate = colors[enemy_id % colors.size()]
		print("Enemy: Using colored square fallback for enemy_", enemy_id_str)

	if debug_label:
		debug_label.text = "ID:%d\nET:%d" % [enemy_id, event_type]

func _process_shooting(delta: float):
	for i in range(3):
		if tur[i] == 0 or freq[i] == 0:
			continue

		eshotwait[i] -= delta * TYRIAN_FPS
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
		var offset_x = float(bx) * SCALE_X
		var offset_y = float(by) * SCALE_Y
		projectile.global_position = global_position + Vector2(offset_x, offset_y)

		# Emituj sygnał do spawnu pocisku (LevelManager doda go do sceny)
		projectile_spawned.emit(projectile)
		# print("Pocisk utworzony na pozycji: ", projectile.global_position, " velocity: ", projectile.velocity)

		# Inkrementuj po wyborze i spawn pocisku, zawijaj po weapon_max
		eshotmultipos[direction_index] = (eshotmultipos[direction_index] + 1) % weapon_max

func _process(delta):
	# Kolejność zgodna z JE_drawEnemy w Tyrianie:
	# 1. fixed_move_y
	# 2. velocity (eyc) — po ewentualnej aktualizacji silnika wahadłowego
	# 3. scroll tła (tempBackMove)

	# --- Stałe przyspieszenie liniowe (xaccel/yaccel) ---
	velocity.x += float(xaccel) * TYRIAN_FPS * delta
	velocity.y += float(yaccel) * TYRIAN_FPS * delta

	# --- 1. Silnik wahadłowy X ---
	if excc != 0:
		exccw -= 1
		if exccw <= 0:
			velocity.x += exccadd
			exccw = exccwmax
			if velocity.x == xrev:
				excc    = -excc
				xrev    = -xrev
				exccadd = -exccadd

	# --- 2. Silnik wahadłowy Y ---
	if eycc != 0:
		eyccw -= 1
		if eyccw <= 0:
			velocity.y += eyccadd
			eyccw = eyccwmax
			if velocity.y == yrev:
				eycc    = -eycc
				yrev    = -yrev
				eyccadd = -eyccadd

	# --- 3. Przeliczenie na px/s Godot i zastosowanie ruchu ---
	var move_x = velocity.x                                              * SCALE_X * TYRIAN_FPS
	var move_y = (float(fixed_move_y) + velocity.y + float(scroll_y))  * SCALE_Y * TYRIAN_FPS

	position.x += move_x * delta
	position.y += move_y * delta

	# --- 4. System strzelania ---
	_process_shooting(delta)

	# --- 5. Usuń poza ekranem (jeden warunek — poprawka podwójnego queue_free) ---
	if position.x < BOUNDS_LEFT  or position.x > BOUNDS_RIGHT \
	or position.y < BOUNDS_TOP   or position.y > BOUNDS_BOTTOM:
		queue_free()
