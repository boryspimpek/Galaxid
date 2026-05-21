extends Node2D

const PLANET_SCENES = [
	"res://scenes/planets/AzurePlanet3D.tscn",
	"res://scenes/planets/CrimsonPlanet3D.tscn",
	"res://scenes/planets/EarthPlanet3D.tscn",
	"res://scenes/planets/EmeraldPlanet3D.tscn",
	"res://scenes/planets/GreenPlanet3D.tscn",
	"res://scenes/planets/PlanetSaturn3D.tscn",
	"res://scenes/planets/SilverPlanet3D.tscn",
]

@export var spawn_interval: float = 3.0
@export var speed_min: float = 50.0
@export var speed_max: float = 150.0

var spawn_timer: float = 0.0

func _ready() -> void:
	spawn_timer = spawn_interval

func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_random_planet()
		spawn_timer = spawn_interval

func spawn_random_planet() -> void:
	var scene_path = PLANET_SCENES[randi() % PLANET_SCENES.size()]
	var planet_scene = load(scene_path)
	if planet_scene == null:
		push_error("Nie udało się załadować sceny: " + scene_path)
		return

	var planet = planet_scene.instantiate()

	var screen_width = 1080.0
	var screen_top = -200.0
	var margin = screen_width * 0.1

	var random_x = randf_range(margin, screen_width - margin)
	var random_speed = randf_range(speed_min, speed_max)

	planet.position = Vector2(random_x, screen_top)
	planet.move_speed = random_speed

	add_child(planet)
