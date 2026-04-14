extends Node

# ============================================================================
# PLAYER SETUP - REJESTR EKWIPUNKU (Zainspirowany tyrian2.c)
# ============================================================================

# --- KADŁUB (SHIP) ---
var ship_id: int = 1           # ID z ships.json (np. USP Talon)

# --- BROŃ PRZEDNIA (FRONT WEAPON) ---
var front_weapon_index: int = 1   # ID z weapon_port.json
var front_weapon_mode: int = 1    # Tryb strzału (1 lub 2)
var front_power_level: int = 1   # Poziom mocy 1-11 (Tyrian miał 11 stopni!)

# --- BROŃ TYLNA (REAR WEAPON) ---
var rear_weapon_index: int = 1    # Indeks z weapon_port.json
var rear_weapon_mode: int = 1  # Tryb strzału (1-2)
var rear_power_level: int = 1

# --- POMOCNICY (SIDEKICKS) ---
var left_sidekick_id: int = 0
var right_sidekick_id: int = 0
var sidekick_level: int = 1    # Poziom ulepszenia pomocników

# --- SYSTEMY ENERGII ---
var generator_id: int = 1      # Odpowiada za tempo ładowania Power
var shield_id: int = 1         # Odpowiada za max pojemność tarczy

# --- ZASOBY (RESOURCES) ---
var credits: int = 1000        # Gotówka na zakupy i upgrade'y
var score: int = 0             # Wynik punktowy
var lives: int = 3             # Liczba pozostałych żyć

# --- SPECJALNE / DODATKI ---
var special_item_id: int = 0   # Np. Repulsor, Flare, itd.
var color_scheme: int = 1      # Wybrany wariant kolorystyczny statku