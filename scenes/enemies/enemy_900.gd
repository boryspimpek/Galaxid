extends Node2D

@export_enum("Zygzak", "Atak") var wybran_sciezka: String = "Zygzak"
@export var speed: float = 150.0

var active_follow: PathFollow2D

func _ready():
	# Wyłączamy wszystkie RemoteTransformy na start
	$Path_Zygzak/PathFollow2D/RemoteTransform2D.update_position = false
	$Path_Atak/PathFollow2D/RemoteTransform2D.update_position = false
	
	# Aktywujemy tylko ten wybrany
	var path_name = "Path_" + wybran_sciezka
	active_follow = get_node(path_name + "/PathFollow2D")
	active_follow.get_node("RemoteTransform2D").update_position = true

func _process(delta):
	if active_follow:
		active_follow.progress += speed * delta
		if active_follow.progress_ratio >= 1.0:
			queue_free()
