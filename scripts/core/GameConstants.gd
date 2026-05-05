extends Node

# ============================================================================
# GAME CONSTANTS - Centralne miejsce dla stałych używanych w całej grze
# ============================================================================

# ---- Granice usuwania (px Godot) ----
const BOUNDS_LEFT = -50
const BOUNDS_RIGHT = 340
const BOUNDS_TOP = -100
const BOUNDS_BOTTOM = 230

# ---- Sceny pocisków ----
var enemy_projectile_scene: PackedScene
var player_projectile_scene: PackedScene

# ---- Sceny eksplozji ----
var explosion_scene: PackedScene
var rep_explosion_scene: PackedScene

func _ready():
	# Załaduj sceny pocisków
	enemy_projectile_scene = preload("res://scenes/enemy_projectile/EnemyProjectile.tscn")
	player_projectile_scene = preload("res://scenes/projectile/Projectile.tscn")
	# Załaduj sceny eksplozji
	explosion_scene     = preload("res://scenes/explosions/Explosion.tscn")
	rep_explosion_scene = preload("res://scenes/explosions/RepExplosion.tscn")
