extends Node

# ============================================================================
# GAME CONSTANTS - Centralne miejsce dla stałych używanych w całej grze
# ============================================================================

# ---- Stałe przeliczeniowe Tyrian -> Godot ----
const TYRIAN_FPS = 30.0

# ---- Granice usuwania (px Godot) ----
# Ekran: 320x200, margines 50px żeby wrogowie nie strzelali spoza ekranu
const BOUNDS_LEFT = -50
const BOUNDS_RIGHT = 370    # 320 + 50
const BOUNDS_TOP = -300
const BOUNDS_BOTTOM = 500   # 200 + 300

# ---- Sceny pocisków ----
var enemy_projectile_scene: PackedScene
var player_projectile_scene: PackedScene

func _ready():
	# Załaduj sceny pocisków
	enemy_projectile_scene = preload("res://scenes/enemy_projectile/EnemyProjectile.tscn")
	player_projectile_scene = preload("res://scenes/projectile/Projectile.tscn")
