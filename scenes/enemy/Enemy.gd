extends Area2D

# ---- Sygnały ----
signal projectile_spawned(projectile)

# ---- Statystyki ----
@export var armor: int = 1
@export var esize: int = 0
@export var value: int = 0
@export var explosiontype: int = 0
var enemy_id: int = 0
var link_num: int = 0

# ---- Ruch ----
var velocity: Vector2 = Vector2(0, 0)
# Ruch bazowy (px/klatkę Tyrian) — ustawiany przez scenę wroga
@export var xmove: int = 0
@export var ymove: int = 0

# Pozycja domyślna dla random spawn
@export var startx: int = 0
@export var starty: int = 0
@export var startxc: int = 0


var projectile_scene: PackedScene

# ---- System strzelania ----
@export var tur: Array = [0, 0, 0]   # ID broni [down, right, left]
@export var freq: Array = [0, 0, 0]  # Częstotliwość strzelania [down, right, left]

# ---- Ruch po ścieżce ----
@export var wybran_sciezka: String = ""
var _active_follow: PathFollow2D = null
var _active_path_speed: float = 0.0
var _active_path_curve: Curve = null

var eshotwait: Array    = [0.0, 0.0, 0.0]  # Licznik cooldown (w klatkach Tyrian)
var eshotwaitmax: Array = [0.0, 0.0, 0.0]  # Maksymalny cooldown z freq
var eshotmultipos: Array = [0, 0, 0]       # Pozycja w cyklu patternów dla każdego kierunku

@onready var visual: Sprite2D = $Visual

func _enter_tree() -> void:
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
	# Warstwa 2 = wróg; maska 4 = pociski gracza, maska 1 = ciało gracza
	collision_layer = 2
	collision_mask  = 5
	body_entered.connect(_on_body_entered)

	# Inicjalizacja systemu strzelania
	for i in range(3):
		var weapon_id = tur[i]
		eshotwaitmax[i] = float(freq[i])
		if weapon_id == 252:
			eshotwait[i] = 1.0  # specjalna broń strzela od razu
		elif weapon_id != 0:
			eshotwait[i] = 20.0  # jak w Tyrianie: JE_makeEnemy zawsze startuje od 20
		else:
			eshotwait[i] = 255.0  # brak broni - duży cooldown

	if visual.texture:
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	if wybran_sciezka != "":
		_setup_path()

	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)

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

		# Oblicz prędkość w zależności od kierunku (zgodnie z kodem Tyrian)
		# direction_index: 0 = down, 1 = right, 2 = left
		var projectile_velocity: Vector2
		
		if aim > 0:
			# Logika aim: celowanie w gracza
			var player = get_tree().get_first_node_in_group("player")
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

		# Utwórz pocisk
		var projectile = projectile_scene.instantiate()
		projectile.velocity = projectile_velocity
		projectile.damage = attack
		projectile.sprite_id = sg
		projectile.anim_max = int(weapon_data.get("weapAni", 0))
		projectile.tx = int(weapon_data.get("tx", 0))
		projectile.ty = int(weapon_data.get("ty", 0))
		projectile.acceleration = int(weapon_data.get("acceleration", 0))
		projectile.accelerationx = int(weapon_data.get("accelerationx", 0))
		projectile.duration = float(pattern.get("del", 255))

		var spawn_origin = visual.global_position if _active_follow else global_position
		projectile.global_position = spawn_origin + Vector2(float(bx), float(by))

		# Emituj sygnał do spawnu pocisku (LevelManager doda go do sceny)
		projectile_spawned.emit(projectile)
		# print("Pocisk utworzony na pozycji: ", projectile.global_position, " velocity: ", projectile.velocity)

		# Inkrementuj po wyborze i spawn pocisku, zawijaj po weapon_max
		eshotmultipos[direction_index] = (eshotmultipos[direction_index] + 1) % weapon_max

func _process(_delta):
	if _active_follow:
		var speed_mult = _active_path_curve.sample(_active_follow.progress_ratio) if _active_path_curve else 1.0
		_active_follow.progress += _active_path_speed * speed_mult
		_process_shooting(_delta)
		if _active_follow.progress_ratio >= 1.0:
			queue_free()
		return

	position += velocity

	# --- 2. System strzelania ---
	_process_shooting(_delta)


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
	var parent := get_parent()
	if parent:
		var enemyground := (explosiontype & 1) == 0
		var explonum   := explosiontype >> 1
		var origin := visual.global_position if _active_follow else global_position
		_spawn_death_explosion(parent, enemyground, explonum, origin)

	if esize == 1:
		SoundManager.play_sound(9)
	else:
		SoundManager.play_sound(8)
	queue_free()


func _spawn_death_explosion(parent: Node, enemyground: bool, explonum: int, origin: Vector2) -> void:
	if esize == 0:
		var explosion: Node2D = GameConstants.explosion_scene.instantiate()
		parent.add_child(explosion)
		explosion.global_position = origin
		explosion.setup(1)
		return

	# Duży wróg (esize == 1) — 4 eksplozje w rogach
	# enemyground == true → powietrzny (typy 7-10), false → naziemny (typy 2-5)
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
