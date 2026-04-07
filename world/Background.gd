extends ParallaxBackground

# Stałe z oryginalnego Tyrian 2000
const TYRIAN_FPS = 30.0
const SCROLL_SPEED_BASE = 1.0  

# Obliczone prędkości (300 px/s)
var current_scroll_velocity = SCROLL_SPEED_BASE * TYRIAN_FPS

var player: CharacterBody2D

func _ready():
	player = get_node_or_null("../Player")
	# Ważne: ustawiamy offset na start
	scroll_offset = Vector2.ZERO

func _process(delta):
	# Logika ruchu w dół
	scroll_offset.y += current_scroll_velocity * delta
	
	# Przesunięcie poziome (parallax)
	if player:
		# Tło przesuwa się w przeciwną stronę do gracza dla efektu parallaxu
		var target_x = -(player.global_position.x - 640) * 0.05
		scroll_offset.x = lerp(scroll_offset.x, target_x, 0.1)
