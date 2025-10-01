extends Node2D
class_name Player

@onready var player_card = $PlayerCard
@onready var player_name_label = $PlayerCard/Name
@onready var turn_indicator = $PlayerCard/TurnIndicator

var player_id = 0
var is_player_turn: bool = false

func _ready() -> void:
	player_name_label.text = "[font_size=16][b]%s[/b][/font_size]" % [str(player_id)]

func _draw() -> void:
	pass

func toggle_turn_indicator(is_turn: bool) -> void:
	turn_indicator.visible = is_turn
