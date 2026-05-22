class_name WeaponStats
extends Resource

@export var weapon_name: String = "Pocisk"
@export var shotRepeat: float = 0.0
@export var multi: int = 0
@export var max_level: int = 0
@export var tx: int = 0
@export var ty: int = 0
@export var aim: int = 0

# Tablica zasobów Pattern, którą edytujesz prosto w Inspektorze
@export var patterns: Array[WeaponPattern] = []

@export var acceleration: int = 0
@export var accelerationx: int = 0
@export var sound: int = 0
@export var trail: int = 255
