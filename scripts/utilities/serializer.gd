extends Node
class_name Serializer

static func serialize_player_seats(player_seats: Dictionary[int, PlayerSeat]) -> Dictionary:
	var player_seats_dict = {}
	for player_id in player_seats:
		player_seats_dict[player_id] = player_seats[player_id].to_dict()
	return player_seats_dict
	
static func deserialize_player_seats(new_player_seats: Dictionary) -> Dictionary[int, PlayerSeat]:
	var deserialized_player_seats: Dictionary[int, PlayerSeat] = {}
	for id in new_player_seats.keys():
		deserialized_player_seats[id] = PlayerSeat.from_dict(new_player_seats[id])
	return deserialized_player_seats
	
static func serialize_connected_players(connected_players: Dictionary[int, ConnectedPlayer]) -> Dictionary:
	var connected_players_dict = {}
	for player_id in connected_players:
		connected_players_dict[player_id] = connected_players[player_id].to_dict()
	return connected_players_dict
	
static func deserialize_connected_players(new_connected_players: Dictionary) -> Dictionary[int, ConnectedPlayer]:
	var deserialized_connected_players: Dictionary[int, ConnectedPlayer] = {}
	for id in new_connected_players.keys():
		deserialized_connected_players[id] = ConnectedPlayer.from_dict(new_connected_players[id])
	return deserialized_connected_players
	
static func serialize_cards(cards: Array[CardData]) -> Array[Dictionary]:
	var card_dict_array: Array[Dictionary] = []
	for card in cards:
		card_dict_array.append(card.to_dict())
	return card_dict_array
	
static func deserialize_cards(cards: Array[Dictionary]) -> Array[CardData]:
	var card_data_array: Array[CardData] = []
	for card in cards:
		card_data_array.append(CardData.from_dict(card))
	return card_data_array
