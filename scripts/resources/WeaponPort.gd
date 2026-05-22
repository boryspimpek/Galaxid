class_name WeaponPort
extends Resource

@export var name: String = ""
@export var cost: int = 0
@export var power_use: int = 0
@export var item_graphic: int = 0
@export var modes_count: int = 1

@export_group("Firing Modes")
# Zamiast tablicy intów [155, 156...], dajesz tablicę referencji do naszych zasobów WeaponStats!
@export var firing_mode_1: Array[WeaponStats] = []
@export var firing_mode_2: Array[WeaponStats] = []