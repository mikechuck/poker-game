extends Node2D

@onready var player_card = $PlayerCard
@onready var player_name_label = $PlayerCard/PlayerName

var player_id = 0

func _ready() -> void:
	player_name_label.text = "Player %s" % [player_id]

func _draw() -> void:
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.BLACK
	style_box.corner_radius_top_left = 20
	style_box.corner_radius_top_right = 20
	style_box.corner_radius_bottom_left = 20
	style_box.corner_radius_bottom_right = 20
	var rect = Rect2(player_card.position.x, player_card.position.y - 10, 200, 50)
	
	draw_style_box(style_box, rect)
