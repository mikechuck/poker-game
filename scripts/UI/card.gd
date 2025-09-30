extends Node

var card_number
var card_suit
var image_node

func _ready():
	image_node = $CardImage

func load_card_image(number, suit):
	var texture: Texture2D = load("res://assets/cards/light/%s-%s.png" % [2, "D"])
	image_node.texture = texture
