extends Area2D

# ============================================================================
# ENEMY — baza wszystkich wrogów.
# Właściwości eksportowane są nadpisywane w scenach Enemy_NNN.tscn.
# ============================================================================

#region Sygnały
signal projectile_spawned(projectile)
#endregion

#region Właściwości eksportowane (nadpisywane per-scena w Enemy_NNN.tscn)

# -- Statystyki --
@export var armor: int = 1
@export var esize: int = 0          # 0 = mały, 1 = duży (wpływa na typ eksplozji)
@export var value: int = 0
@export var explosiontype: int = 0  # bit 0: naziemny/powietrzny; bity 1+: liczba wybuchów

# -- Ruch bazowy (px/klatkę Tyrian, ustawiany przez EnemySpawner lub scenę) --
@export var xmove: int = 0
@export var ymove: int = 0

# -- Pozycja startowa dla random spawn --
@export var startx: int = 0
@export var starty: int = 0
@export var startxc: int = 0

# -- System strzelania --
@export var tur: Array  = [0, 0, 0]   # ID broni [down, right, left]
@export var freq: Array = [0, 0, 0]   # Częstotliwość strzałów [down, right, left]

# -- Ruch po ścieżce --
@export var wybran_sciezka: String = ""  # Ścieżka do węzła Path2D (jeśli pusty: swobodny ruch)

#endregion

#region Stan wewnętrzny

var enemy_id: int = 0
var link_num: int = 0

var velocity: Vector2 = Vector2.ZERO
var projectile_scene: PackedScene

# Śledzenie ścieżki (aktywne gdy wybran_sciezka != "")
var _active_follow: PathFollow2D = null
var _active_path_speed: float = 0.0
var _active_path_curve: Curve = null

# Timery strzelania (per slot broni)
var eshotwait:    Array = [0.0, 0.0, 0.0]  # Aktualny cooldown
var eshotwaitmax: Array = [0.0, 0.0, 0.0]  # Maksymalny cooldown (z freq)
var eshotmultipos: Array = [0, 0, 0]       # Pozycja w cyklu patternów

var _player: Node2D
var _weapon_cache: Array = [null, null, null]

@onready var visual: Sprite2D = $Visual

#endregion

# ============================================================================
# INICJALIZACJA
# ============================================================================

func _enter_tree() -> void:
	# Wyłącz RemoteTransform2D zanim scena trafi do drzewa —
	# włączymy go dopiero gdy wybrana ścieżka zostanie potwierdzona.
	for child in get_children():
		if not child is Path2D:
			continue
		for follow in child.get_children():
			if not follow is PathFollow2D:
				continue
			for rt in follow.get_children():
				if rt is RemoteTransform2D:
					rt.update_position = false

func _ready():
	add_to_group("enemies")
	collision_layer = 2
	collision_mask  = 5
	body_entered.connect(_on_body_entered)

	velocity = Vector2(float(xmove), float(ymove))
	projectile_scene = GameConstants.enemy_projectile_scene

	_init_shooting_timers()

	if wybran_sciezka != "":
		_setup_path()

	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)
	$VisibleOnScreenNotifier2D.screen_entered.connect(_on_screen_entered)
	_player = get_tree().get_first_node_in_group("player")
	refresh_weapon_cache()
	set_process(false)

func _init_shooting_timers():
	# Startowe cooldowny zgodne z logiką Tyrian (JE_makeEnemy):
	#   252 = specjalna broń → strzela natychmiast
	#   0   = brak broni     → wielki cooldown (255)
	#   inne                 → 20 klatek opóźnienia startowego
	for i in range(3):
		eshotwaitmax[i] = float(freq[i])
		match tur[i]:
			252: eshotwait[i] = 1.0
			0:   eshotwait[i] = 255.0
			_:   eshotwait[i] = 20.0

func _setup_path():
	for child in get_children():
		if child is Path2D:
			var rt = child.get_node_or_null("PathFollow2D/RemoteTransform2D")
			if rt:
				rt.update_position = false

	var path_node = get_node_or_null(wybran_sciezka)
	if path_node and path_node is Path2D:
		var follow = path_node.get_node_or_null("PathFollow2D")
		if follow:
			_active_follow = follow
			for rt in follow.get_children():
				if rt is RemoteTransform2D:
					rt.update_position = true
			_active_path_speed = path_node.speed
			_active_path_curve = path_node.speed_curve

func _on_screen_entered():
	set_process(true)

func _on_screen_exited():
	# Podczas podążania za ścieżką ignorujemy screen_exited —
	# visual może wychodzić poza ekran (np. leci w górę) ale wróg
	# powinien żyć dopóki ścieżka trwa. Usuń dopiero gdy ścieżka
	# skończyła się i wróg w trybie swobodnym opuści ekran.
	if _active_follow:
		return
	queue_free()

func refresh_weapon_cache():
	for i in range(3):
		_weapon_cache[i] = DataManager.get_weapon_by_id(tur[i]) if tur[i] != 0 else null

# ============================================================================
# PĘTLA GŁÓWNA
# ============================================================================

func _process(_delta):
	if _active_follow:
		var speed_mult = _active_path_curve.sample(_active_follow.progress_ratio) if _active_path_curve else 1.0
		_active_follow.progress += _active_path_speed * speed_mult
		_process_shooting(_delta)
		if _active_follow.progress_ratio >= 1.0:
			# Ścieżka skończona → przejdź na swobodny ruch (velocity).
			# screen_exited wyczyści wroga gdy opuści ekran.
			_active_follow = null
		return

	position += velocity
	_process_shooting(_delta)

# ============================================================================
# SYSTEM STRZELANIA
# ============================================================================

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
		push_error("Enemy: projectile_scene pusty (enemy_id=%d)" % enemy_id)
		return

	var weapon_id   = int(tur[direction_index])
	var weapon_data: Dictionary = _weapon_cache[direction_index] if _weapon_cache[direction_index] != null else {}

	if weapon_data.is_empty():
		push_error("Enemy: nie znaleziono broni o ID=%d (enemy_id=%d)" % [weapon_id, enemy_id])
		return

	var patterns     = weapon_data.get("patterns", [])
	if patterns.is_empty():
		return

	var weapon_multi = int(weapon_data.get("multi", 1))
	var weapon_max   = int(weapon_data.get("max", 1))
	var aim          = int(weapon_data.get("aim", 0))

	for _i in range(weapon_multi):
		var temp_pos = eshotmultipos[direction_index]
		if temp_pos >= patterns.size():
			temp_pos = 0

		var pattern = patterns[temp_pos]
		var attack  = pattern.get("attack", 1)
		var sx      = pattern.get("sx", 0)
		var sy      = pattern.get("sy", 0)
		var bx      = pattern.get("bx", 0)
		var by      = pattern.get("by", 0)
		var sg      = pattern.get("sg", 0)

		var projectile_velocity: Vector2
		if aim > 0:
			projectile_velocity = _calc_aim_velocity(aim, sx, sy)
		else:
			projectile_velocity = _calc_dir_velocity(direction_index, sx, sy)

		var projectile = projectile_scene.instantiate()
		projectile.velocity      = projectile_velocity
		projectile.damage        = attack
		projectile.sprite_id     = sg
		projectile.anim_max      = int(weapon_data.get("weapAni", 0))
		projectile.tx            = int(weapon_data.get("tx", 0))
		projectile.ty            = int(weapon_data.get("ty", 0))
		projectile.acceleration  = int(weapon_data.get("acceleration", 0))
		projectile.accelerationx = int(weapon_data.get("accelerationx", 0))
		projectile.duration      = float(pattern.get("del", 255))

		var spawn_origin = visual.global_position if _active_follow else global_position
		projectile.global_position = spawn_origin + Vector2(float(bx), float(by))

		projectile_spawned.emit(projectile)
		eshotmultipos[direction_index] = (eshotmultipos[direction_index] + 1) % weapon_max

func _calc_aim_velocity(aim: int, sx: int, sy: int) -> Vector2:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(_player):
		return Vector2(float(sx), float(sy))
	var diff = _player.global_position - global_position
	var mag  = max(abs(diff.x), abs(diff.y))
	if mag == 0:
		return Vector2(float(sx), float(sy))
	return Vector2(round(diff.x / mag * aim), round(diff.y / mag * aim))

func _calc_dir_velocity(direction_index: int, sx: int, sy: int) -> Vector2:
	# Prędkość pocisku w zależności od kierunku strzelania (obroty 90°).
	match direction_index:
		1: return Vector2(float(sy),  float(-sx))   # right
		2: return Vector2(float(-sy), float(-sx))   # left
		_: return Vector2(float(sx),  float(sy))    # down (domyślny)

# ============================================================================
# SYSTEM OBRAŻEŃ I ŚMIERCI
# ============================================================================

func take_damage(amount: int):
	armor -= amount
	if armor <= 0:
		die()
	else:
		SoundManager.play_sound(3)  # S_ENEMY_HIT

func die():
	var parent := get_parent()
	if parent:
		var enemyground := (explosiontype & 1) == 0
		var explonum    := explosiontype >> 1
		var origin      := visual.global_position if _active_follow else global_position
		_spawn_death_explosion(parent, enemyground, explonum, origin)

	SoundManager.play_sound(9 if esize == 1 else 8)
	queue_free()

func _spawn_death_explosion(parent: Node, enemyground: bool, explonum: int, origin: Vector2) -> void:
	if esize == 0:
		var explosion: Node2D = GameConstants.explosion_scene.instantiate()
		parent.add_child(explosion)
		explosion.global_position = origin
		explosion.setup(1)
		return

	# Duży wróg — 4 eksplozje w rogach.
	# enemyground: false = powietrzny (typy 7-10), true = naziemny (typy 2-5)
	var corner_types: Array = [2, 4, 3, 5] if enemyground else [7, 9, 8, 10]
	var offsets := [Vector2(-6, -14), Vector2(6, -14), Vector2(-6, -2), Vector2(6, -2)]
	for i in range(4):
		var explosion: Node2D = GameConstants.explosion_scene.instantiate()
		parent.add_child(explosion)
		explosion.global_position = origin + offsets[i]
		explosion.setup(corner_types[i])

	if explonum > 0:
		var big   := explonum > 10
		var burst := explonum - 10 if big else explonum
		var rep: Node2D = GameConstants.rep_explosion_scene.instantiate()
		parent.add_child(rep)
		rep.global_position = origin
		rep.setup(burst, big)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		var ds = body.get_node_or_null("DamageSystem")
		if ds:
			ds.take_damage(armor)
		die()
