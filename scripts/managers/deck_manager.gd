extends Node

var deck_cards: Array[CardData]
var card_types: Array[CardData]
var suits: Array[String] = ["D", "H", "C", "P"]
var faces: Array[String] = ["J", "Q", "K", "A"]

func _ready():
	for suit in suits:
		for i in range(1, 11):
			var new_card = CardData.new()
			new_card.number = 
			deck_cards.append()
