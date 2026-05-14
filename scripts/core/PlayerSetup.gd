extends Node

# ============================================================================
# PLAYER SETUP - REJESTR EKWIPUNKU (Zainspirowany tyrian2.c)
# ============================================================================

# --- KADŁUB (SHIP) ---
@export var ship_id: int = 1

# --- BROŃ PRZEDNIA (FRONT WEAPON) ---
@export var front_weapon_index: int = 1
@export var front_weapon_mode: int = 1
@export var front_power_level: int = 1

# --- BROŃ TYLNA (REAR WEAPON) ---
@export var rear_weapon_index: int = 1
@export var rear_weapon_mode: int = 1
@export var rear_power_level: int = 1

# --- POMOCNICY (SIDEKICKS) ---
@export var left_sidekick_id: int = 0
@export var right_sidekick_id: int = 0
@export var sidekick_level: int = 1

# --- SYSTEMY ENERGII ---
@export var generator_id: int = 1
@export var shield_id: int = 1

# --- ZASOBY (RESOURCES) ---
@export var credits: int = 1000
@export var score: int = 0
@export var lives: int = 3

# --- SPECJALNE / DODATKI ---
@export var special_item_id: int = 0
@export var color_scheme: int = 1
