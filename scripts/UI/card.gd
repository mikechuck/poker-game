extends Node

var card_number
var card_suit
var image_node
var number: int
var value: String
var suit: String

func _ready():
	image_node = get_node("CardImage")
	var texture = load("res://assets/cards/light/%s-%s.png" % [value, suit])
	image_node.texture = texture
