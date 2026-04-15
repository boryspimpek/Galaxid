extends Control

# ============================================================================
# GENERATOR INFO UI - Wyświetlanie informacji o generatorze (tylko do odczytu)
# ============================================================================

@onready var generator_name_label: Label = $VBoxContainer/GeneratorNameLabel
@onready var power_label: Label = $VBoxContainer/PowerLabel
@onready var power_add_label: Label = $VBoxContainer/PowerAddLabel

func _ready():
	# UI jest widoczne od początku
	show()
	print("GeneratorInfoUI: Ready")

func _process(_delta):
	# Znajdź gracza i aktualizuj wyświetlanie
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player:
		# Aktualna wartość energii
		power_label.text = "Power: " + str(int(player.power)) + "/" + str(int(player.power_max))
		
		# Szybkość regeneracji
		power_add_label.text = "Power Regen: " + str(player.power_add) + " / frame"
		
		# Nazwa generatora
		var generator_id = PlayerSetup.generator_id
		var generator = DataManager.get_generator_by_id(generator_id)
		if not generator.is_empty():
			var generator_name = generator.get("name", "Unknown")
			generator_name_label.text = "Generator: " + generator_name
		else:
			generator_name_label.text = "Generator: Unknown"
	else:
		generator_name_label.text = "Player not found"
		power_label.text = "Power: ?/?"
		power_add_label.text = "Power Regen: ? / frame"
