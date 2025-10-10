extends Node

var is_server: bool
var game_manager = null

### Deck fields
var cards: Array[CardData]
var card_types: Array[CardData]
var suits: Array[String] = ["D", "H", "C", "P"]
var faces: Dictionary[String, int] = {"J": 11, "Q": 12, "K": 13, "A": 14}
var deck: Array[CardData]

func _ready():
	game_manager = get_parent().get_node("GameManager")
	
	for suit in suits:
		for i in range(2, 11):
			var new_card = CardData.new()
			new_card.number = i
			new_card.value = str(i)
			new_card.suit = suit
			cards.append(new_card)
		for i in faces.keys():
			var new_card = CardData.new()
			new_card.number = faces[i]
			new_card.value = i
			new_card.suit = suit
			cards.append(new_card)

func shuffle_deck():
	deck = cards.duplicate()
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
	

######### Helper functions for calulation hand values. Put here to keep game_manager clean #########

func find_highest_hand_value(sorted_cards) -> int: 
	var hand_value: int = 0
	
	hand_value = get_royal_flush(sorted_cards)
	if (hand_value != 0):
		return hand_value
		
	hand_value = get_straight_flush_score(sorted_cards)
	if (hand_value != 0):
		return hand_value
	
	hand_value = get_four_kind_score(sorted_cards)
	if (hand_value != 0):
		return hand_value
		
	hand_value = get_full_house_score(sorted_cards)
	if (hand_value != 0):
		return hand_value
		
	hand_value = get_flush_score(sorted_cards)
	if (hand_value != 0):
		return hand_value
		
	hand_value = get_straight_score(sorted_cards)
	if (hand_value != 0):
		return hand_value
	
	hand_value = get_three_kind_score(sorted_cards)
	if (hand_value != 0):
		return hand_value
		
	hand_value = get_two_pair_score(sorted_cards)
	if (hand_value != 0):
		return hand_value
		
	hand_value = get_one_pair_score(sorted_cards)
	if (hand_value != 0):
		return hand_value
		
	hand_value = get_high_card_score(sorted_cards)
	return hand_value
		
func get_royal_flush(sorted_cards) -> int:
	var suit: String = sorted_cards[0].suit
	for i in sorted_cards.size():
		# Ensure all the same suit
		if (sorted_cards[i].suit != suit):
			return 0
	# Ensure they are face cards
	if (
		sorted_cards[0].number == 14 &&
		sorted_cards[1].number == 13 &&
		sorted_cards[2].number == 12 &&
		sorted_cards[3].number == 11 && 
		sorted_cards[4].number == 10
	):
		return 1 * pow(10, HandRanks.Rank.RoyalFlush)
	else:
		return 0

func get_straight_flush_score(sorted_cards) -> int:
	var suit: String = sorted_cards[0].suit
	
	# Ensure all the same suit
	for i in sorted_cards.size():
		if (sorted_cards[i].suit != suit):
			return 0
		
	# Ensure they are consecutive
	for i in range (1, sorted_cards.size()):
		if (sorted_cards[i].number + 1 != sorted_cards[i - 1].number):
			return 0
			
	return sorted_cards[0].number * pow(10, HandRanks.Rank.StraightFlush)
	
func get_four_kind_score(sorted_cards) -> int:
	var previous_number: int = 0
	var pair_number: int = 0
	#for card in sorted_cards:
	return 0
	
func get_full_house_score(sorted_cards) -> int:
	return 0
	
func get_flush_score(sorted_cards) -> int:
	return 0

func get_straight_score(sorted_cards) -> int:
	return 0
	
func get_three_kind_score(sorted_cards) -> int:
	return 0
	
func get_two_pair_score(sorted_cards) -> int:
	return 0
	
func get_one_pair_score(sorted_cards) -> int:
	var previous_number: int = 0
	var one_pair_number: int = 0
	for i in sorted_cards.size():
		var card = sorted_cards[i]
		if previous_number == card.number:
			one_pair_number = card.number
			# Remove the pair from the cards so that we can grab the kicker if needed
			sorted_cards.remove_at(i)
			sorted_cards.remove_at(i - 1)
			break
		previous_number = card.number
	return one_pair_number * pow(10, HandRanks.Rank.OnePair)

func get_high_card_score(sorted_cards) -> int:
	var high_card_score = sorted_cards[0].number * pow(10, HandRanks.Rank.HighCard)
	return high_card_score
	
