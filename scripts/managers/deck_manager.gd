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
	Log.message("Card delt: [%s, %s]" % [new_card.number, new_card.suit])
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
	# Remove any duplicates
	var unique_numbers = []
	for card in sorted_cards:
		if not unique_numbers.has(card.number):
			unique_numbers.append(card.number)
	for i in range (1, unique_numbers.size()):
#		((seat_number) % 8) + 1
#		A, 5, 4, 3, 2
#		0, 1, 2, 3, 4
		if (sorted_cards[i].number + 1 != sorted_cards[i - 1].number):
			return 0
			
	return sorted_cards[0].number * pow(10, HandRanks.Rank.StraightFlush)
	
func get_four_kind_score(sorted_cards) -> int:
	var pair_count: int = 0
	var pair_number: int = 0
	for card in sorted_cards:
		if pair_number == 0:
			pair_number = card.number
		if card.number == pair_number:
			pair_count += 1
			if pair_count == 4:
				return pair_number  * pow(10, HandRanks.Rank.FourKind)
		else:
			pair_count = 1
			pair_number = card.number
	return 0
	
func get_full_house_score(sorted_cards) -> int:
	var three_kind_score = get_three_kind_score(sorted_cards)
	var one_pair_score = get_one_pair_score(sorted_cards)
	if (three_kind_score > 0 && one_pair_score > 0):
		# Return the three pair score, if there is another three pair score 
		# with the same cards, use the one pair as the kicker
		return three_kind_score  * pow(10, HandRanks.Rank.FullHouse)
	return 0
	
func get_flush_score(sorted_cards) -> int:
	var suit = null
	for card in sorted_cards:
		if suit == null:
			suit = card.suit
		if card.suit != suit:
			return 0
	return sorted_cards[0].number  * pow(10, HandRanks.Rank.Flush)

func get_straight_score(sorted_cards) -> int:
	for i in range (1, sorted_cards):
		if sorted_cards[i].number + 1 != sorted_cards[i - 1].number:
			return 0
	return sorted_cards[0].number  * pow(10, HandRanks.Rank.Straight)
	
	# This function assumes sorted_cards is an array of 5 cards,
	# sorted by number in descending order (e.g., [King, 10, 9, 8, 2]).
	# Ace is represented by the number 14.

	# 1. Check for the special case: Ace-low straight (A-2-3-4-5)
	# When sorted descending, this unique hand is [14, 5, 4, 3, 2]
	var test = sorted_cards.has()
	var is_wheel = (
		sorted_cards[0].number == 14 and
		sorted_cards[1].number == 5 and
		sorted_cards[2].number == 4 and
		sorted_cards[3].number == 3 and
		sorted_cards[4].number == 2
	)

	if is_wheel:
		# In a wheel, the 5 is considered the high card for ranking.
		# A-5 straight loses to a 2-6 straight.
		return 5

	# 2. If it's not a wheel, check for a "normal" straight
	# Note: The loop range was also fixed from your original code.
	for i in range(1, sorted_cards.size()):
		# If any card is not exactly one less than the previous card,
		# it's not a consecutive sequence.
		if sorted_cards[i].number + 1 != sorted_cards[i - 1].number:
			return 0 # Not a straight

	# 3. If the loop finishes, it's a standard straight.
	# The score is the value of the highest card.
	return sorted_cards[0].number
	
func get_three_kind_score(sorted_cards) -> int:
	var kind_number = null
	var kind_count = 0
	for card in sorted_cards:
		if kind_number == null:
			kind_number == card.number
		if card.number == kind_number:
			kind_count += 1
		else:
			kind_number = card.number
			kind_count = 1
		if kind_count == 3:
			return kind_number  * pow(10, HandRanks.Rank.ThreeKind)
	return 0
	
func get_two_pair_score(sorted_cards) -> int:
	var temp_sorted_cards = sorted_cards.duplicate(true)
	var one_pair_number = get_one_pair_score(temp_sorted_cards)
	var two_pair_number = get_one_pair_score(temp_sorted_cards, one_pair_number)
	if (one_pair_number != 0 && two_pair_number != 0):
		return one_pair_number * pow(10, HandRanks.Rank.TwoPair)
	return 0
	
func get_one_pair_score(sorted_cards, number_to_ignore = 0) -> int:
	var previous_number: int = 0
	var one_pair_number: int = 0
	for i in sorted_cards.size():
		var card = sorted_cards[i]
		if previous_number == card.number:
			one_pair_number = card.number
			break
		if (card.number != number_to_ignore):
			previous_number = card.number
	return one_pair_number * pow(10, HandRanks.Rank.OnePair)

func get_high_card_score(sorted_cards) -> int:
	var high_card_score = sorted_cards[0].number
	return high_card_score  * pow(10, HandRanks.Rank.HighCard)
	
