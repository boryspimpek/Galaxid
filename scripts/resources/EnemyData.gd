class_name EnemyData
extends Resource

@export var armor: int = 1
@export var esize: int = 0

# Ruch bazowy (piksele na klatkę Tyriana)
@export var xmove: int = 0
@export var ymove: int = 0

# Losowe przyspieszenie
@export var xaccel: int = 0
@export var yaccel: int = 0

# Silnik wahadłowy
@export var xcaccel: int = 0
@export var ycaccel: int = 0
@export var xrev: int = 0
@export var yrev: int = 0

# Broń: ID broni [down, right, left] i częstotliwości strzelania
@export var tur: Array[int] = [0, 0, 0]
@export var freq: Array[int] = [0, 0, 0]

# Pozycja domyślna dla random spawn
@export var startx: int = 0
@export var starty: int = 0
@export var startxc: int = 0
