extends Node3D

@onready var name_label: Label3D = $NameLabel

func set_player_name(player_name: String) -> void:
	if name_label:
		name_label.text = player_name

