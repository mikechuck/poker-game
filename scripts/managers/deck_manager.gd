extends Node

var is_server: bool
var game_manager = null

### Deck fields
var cards: Array[CardData]
var card_types: Array[CardData]
var suits: Array[String] = ["D", "H", "C", "P"]
var faces: Array[String] = ["J", "Q", "K", "A"]
var deck: Array[CardData]

func _ready():
	game_manager = get_parent().get_node("GameManager")
	
	for suit in suits:
		for i in range(2, 11):
			var new_card = CardData.new()
			new_card.number = str(i)
			new_card.suit = suit
			cards.append(new_card)
		for face in faces:
			var new_card = CardData.new()
			new_card.number = face
			new_card.suit = suit
			cards.append(new_card)

func shuffle_deck():
	deck = cards
	for i in range(0, 10):
		deck = _shuffle_deck(deck)
			
func _shuffle_deck(source_deck: Array[CardData]) -> Array[CardData]:
	var shuffled_deck: Array[CardData] = []
	for i in range(0, 52):
		var randomIndex = randi() % (52 - i)
		shuffled_deck.append(source_deck[randomIndex])
		source_deck.remove_at(randomIndex)
	return shuffled_deck
	
func deal_card() -> CardData:
	var new_card = deck[0]
	deck.remove_at(0)
	print("Card delt: [%s, %s]" % [new_card.number, new_card.suit])
	return new_card
