extends ParallaxBackground

# Stałe z Tyrian
const TYRIAN_FPS = 15.0
const SCALE_Y    = 720.0 / 200.0   # = 3.6  (przeliczenie Tyrian → Godot dla osi Y)

# Prędkości scrollingu w jednostkach Tyrian (px/klatkę @ 30 FPS)
# Oryginalne wartości domyślne z Tyrian
var back_move:  int = 1   # tło 1 — Ground
var back_move2: int = 2   # tło 2 — Sky  (główny scroll widoczny dla gracza)
var back_move3: int = 3   # tło 3 — Top

# Prędkość scrollingu w px/s Godot (oś Y)
# Przeliczenie: back_move [px/klatkę Tyrian] * SCALE_Y * TYRIAN_FPS = [px/s Godot]
# Przykład dla domyślnego back_move=2: 2 * 3.6 * 30 = 216 px/s
var scroll_velocity_y: float = float(back_move) * SCALE_Y * TYRIAN_FPS

var player: CharacterBody2D

func _ready():
	player = get_node_or_null("../Player")
	scroll_offset = Vector2.ZERO

func _process(delta):
	# Scrolling pionowy — tło przesuwa się w dół
	scroll_offset.y += scroll_velocity_y * delta

	# Parallax poziomy za graczem (kosmetyczny, niezwiązany z Tyrianem)
	if player:
		var target_x = -(player.global_position.x - 640) * 0.05
		scroll_offset.x = lerp(scroll_offset.x, target_x, 0.1)

func set_scroll_speed(p_back_move: int, p_back_move2: int, p_back_move3: int):
	"""Aktualizuje prędkości scrollingu po evencie type 2."""
	back_move  = p_back_move
	back_move2 = p_back_move2
	back_move3 = p_back_move3

	# Przelicz nową prędkość Godot dla tła Sky (back_move)
	# back_move [px/klatkę Tyrian] × SCALE_Y × TYRIAN_FPS = [px/s Godot]
	scroll_velocity_y = float(back_move) * SCALE_Y * TYRIAN_FPS

	# Dodatkowe przeliczenie dla Ground (dla porównania z przeciwnikami)
	var ground_scroll_px_s = float(back_move) * SCALE_Y * TYRIAN_FPS

	print("Background scroll: back_move=", back_move, " (", ground_scroll_px_s, " px/s Ground)",
		  " back_move2=", back_move2, " (", scroll_velocity_y, " px/s Sky)",
		  " back_move3=", back_move3)
