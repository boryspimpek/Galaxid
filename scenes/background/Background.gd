extends Node2D


var back_move: int = 1
var back_move2: int = 2
var back_move3: int = 3

var scroll_velocity_y = float(back_move)
var player: CharacterBody2D

@onready var background_rect: TextureRect = $BackgroundRect
@onready var background_rect2: TextureRect = $BackgroundRect2  # druga kopia!

func _ready():
	player = get_node_or_null("../Player")
	background_rect.position = Vector2.ZERO
	background_rect2.position = Vector2(0, -720)  # druga kopia nad pierwszą

func _process(_delta):
	background_rect.position.y += scroll_velocity_y
	background_rect2.position.y += scroll_velocity_y

	# Gdy kopia zejdzie poza dolną krawędź — wskakuje z powrotem na górę
	if background_rect.position.y >= 720:
		background_rect.position.y -= 1440
	if background_rect2.position.y >= 720:
		background_rect2.position.y -= 1440


func set_scroll_speed(p_back_move: int, p_back_move2: int, p_back_move3: int):
	back_move = p_back_move
	back_move2 = p_back_move2
	back_move3 = p_back_move3
	scroll_velocity_y = float(back_move)

# Przesuwa tło do pozycji odpowiadającej start_dist.
# TextureRecty scrollują z prędkością back_move (tak samo jak level_distance),
# więc ich offset = start_dist mod 1440.
func seek_to(dist1: int, dist2: int, dist3: int) -> void:
	var offset := fmod(float(dist1), 1440.0)
	background_rect.position.y  = offset
	background_rect2.position.y = offset - 1440.0
	if background_rect.position.y >= 720.0:
		background_rect.position.y  -= 1440.0
	if background_rect2.position.y >= 720.0:
		background_rect2.position.y -= 1440.0
	var tile_bg := get_node_or_null("TileBackground")
	if tile_bg and tile_bg.has_method("seek_to"):
		tile_bg.seek_to(dist1, dist2, dist3)
