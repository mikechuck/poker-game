extends Node2D

@onready var player_name_label = $PlayerCard/PlayerName

func _ready() -> void:
	player_name_label.text = "Player 2"

func _draw() -> void:
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.BLACK
	style_box.corner_radius_top_left = 20
	style_box.corner_radius_top_right = 20
	style_box.corner_radius_bottom_left = 20
	style_box.corner_radius_bottom_right = 20
	
	var rect = Rect2(0, 0, 100, 50)
	
	draw_style_box(style_box, rect)
