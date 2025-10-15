extends Node2D
class_name Player

### Scenes
@export var card_scene: PackedScene = preload("res://scenes/UI/card.tscn")

@onready var player_card_node = $PlayerCard
@onready var player_name_label_node = $PlayerCard/Name
@onready var turn_indicator_node = $PlayerCard/TurnIndicator
@onready var cash_amount_node = $PlayerCard/CashAmount
@onready var folded_badge_node = $PlayerCard/FoldBadge
@onready var winner_badge_node = $PlayerCard/WinnerBadge
@onready var bet_badge_node = $PlayerCard/BetBadge
@onready var card_back_1 = $PlayerCard/CardBack1
@onready var card_back_2 = $PlayerCard/CardBack2
@onready var game_manager = get_tree().root.get_node("Game/GameManager")

var card_front_1 = null
var card_front_2 = null

var player_id = 0
var is_player_turn: bool = false
var hand_cash: int = 0
var is_folded: bool = false
var is_big_blind: bool = false
var is_small_blind: bool = false
var bet_value: int = 0
var show_cards: bool = false
var hole_cards: Array[CardData] = []
var is_winner: bool = false

func _ready() -> void:
	player_name_label_node.text = "[font_size=16][b]%s[/b][/font_size]" % [str(player_id)]
	cash_amount_node.text = "$" + str(hand_cash)
	
	if is_player_turn && game_manager.game_state_data.game_state != GameState.State.HandOver:
		turn_indicator_node.visible = true
		
	var is_ante_turn = (is_small_blind || is_big_blind) && game_manager.game_state_data.game_state == GameState.State.BetHole
		
	# Badge logic, only want one
	if is_folded:
		player_card_node.set_modulate("aaaaaa")
		folded_badge_node.visible = true
	elif (is_ante_turn && bet_value == 0):
		if is_small_blind:
			bet_badge_node.visible = true
			bet_badge_node.get_node("Text").text = "SB"
		elif is_big_blind:
			bet_badge_node.visible = true
			bet_badge_node.get_node("Text").text = "BB"
	elif (game_manager.game_state_data.game_state != GameState.State.PreHand):
		bet_badge_node.visible = true
		bet_badge_node.get_node("Text").text = "$%s" % bet_value
	
	# Cards logic
	if (game_manager.game_state_data.game_state >= GameState.State.HandOver):
		show_cards = true
		
	if (is_winner):
		bet_badge_node.visible = false
		folded_badge_node.visible = false
		winner_badge_node.visible = true
		turn_indicator_node.visible = true
		
	if show_cards:
		card_back_1.visible = false
		card_back_2.visible = false
		for i in range(1, 3):
			var card_back_node = player_card_node.get_node("CardBack" + str(i))
			var card_data = hole_cards[i - 1]
			var card_instance = card_scene.instantiate()
			card_instance.value = card_data.value
			card_instance.suit = card_data.suit
			card_instance.position = card_back_node.position
			card_instance.scale = Vector2(0.41, 0.41)
			player_card_node.add_child(card_instance)
	else:
		if (card_front_1 != null): card_front_1.visible = false
		if (card_front_2 != null): card_front_2.visible = false
		if (game_manager.game_state_data.game_state == GameState.State.PreHand):
			card_back_1.visible = false
			card_back_2.visible = false
		else:
			card_back_1.visible = true
			card_back_2.visible = true
