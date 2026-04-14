extends Node

# ============================================================================
# WEAPON SYSTEM - Logika strzelania
# ============================================================================

# --- Referencje ---
var player: CharacterBody2D
var projectile_scene: PackedScene

# --- Konfiguracja ---
var fire_cooldown: float = 0.1
var fire_timer: float = 0.0

func _ready():
	player = get_parent()
	# TODO: Załaduj projectile_scene z DataManager

func _physics_process(delta):
	if fire_timer > 0:
		fire_timer -= delta

func shoot():
	if fire_timer <= 0:
		# TODO: Stwórz projectile
		# TODO: Ustaw pozycję z Muzzle
		fire_timer = fire_cooldown
