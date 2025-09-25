extends Node2D
class_name Player

@onready var player_card = $PlayerCard
@onready var player_name_label = $PlayerCard/Name

var player_id = 0

func _ready() -> void:
	player_name_label.text = "[font_size=16][b]%s[/b][/font_size]" % [str(player_id)]

func _draw() -> void:
	pass
