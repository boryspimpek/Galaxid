extends Node2D

const ASTEROID_SCENES = [
	"res://scenes/asteroids/asteroid.tscn",
]

@export var spawn_interval: float = 3.0
@export var speed_min: float = 50.0
@export var speed_max: float = 150.0
@export var armor_override: int = 0
@export var preprocess_time: float = 20.0

var spawn_timer: float = 0.0

func _ready() -> void:
	spawn_timer = spawn_interval
	_preprocess(preprocess_time)

func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_random_asteroid()
		# print("Asteroid spawned")
		spawn_timer = spawn_interval

func _preprocess(time: float) -> void:
	var elapsed := 0.0
	while elapsed < time:
		elapsed += spawn_interval
		spawn_random_asteroid()
		var last = get_child(get_child_count() - 1)
		last.position.y += float(last.ymove) * (time - elapsed)

func spawn_random_asteroid() -> void:
	var scene_path = ASTEROID_SCENES[randi() % ASTEROID_SCENES.size()]
	var asteroid_scene = load(scene_path)
	if asteroid_scene == null:
		push_error("Nie udało się załadować sceny: " + scene_path)
		return

	var asteroid = asteroid_scene.instantiate()

	var screen_width = 1080.0
	var screen_top = -200.0
	var margin = screen_width * 0.1

	var random_x = randf_range(margin, screen_width - margin)
	var random_speed = randf_range(speed_min, speed_max)

	asteroid.position = Vector2(random_x, screen_top)
	asteroid.ymove = int(random_speed)
	if armor_override > 0:
		asteroid.armor = armor_override

	add_child(asteroid)
	asteroid.set_process(true)
