extends Node

# ============================================================================
# GAME CONSTANTS - Centralne miejsce dla stałych używanych w całej grze
# ============================================================================

# ---- Stałe przeliczeniowe Tyrian -> Godot ----
const TYRIAN_FPS = 15.0
const SCALE_X = 1280.0 / 320.0   # = 4.0
const SCALE_Y = 720.0 / 200.0   # = 3.6

# ---- Granice usuwania (px Godot) ----
# Ekran: 1280x720, margines 150px żeby wrogowie nie strzelali spoza ekranu
const BOUNDS_LEFT = -150
const BOUNDS_RIGHT = 1430   # 1280 + 150
const BOUNDS_TOP = -1000
const BOUNDS_BOTTOM = 870   # 720 + 150

# ---- Sceny pocisków ----
var enemy_projectile_scene: PackedScene
var player_projectile_scene: PackedScene

func _ready():
	# Załaduj sceny pocisków
	enemy_projectile_scene = preload("res://scenes/enemy_projectile/EnemyProjectile.tscn")
	player_projectile_scene = preload("res://scenes/projectile/Projectile.tscn")
