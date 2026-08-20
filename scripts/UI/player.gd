extends Node2D
class_name Player

### Scenes
@export var card_scene: PackedScene = preload("res://scenes/UI/card.tscn")

@onready var player_card_node: Node2D = $PlayerCard
@onready var player_details_card_node: Sprite2D = $PlayerCard/DetailsCard
@onready var player_profile_picture_node: Sprite2D = $PlayerCard/ProfilePicture
@onready var player_name_label_node: RichTextLabel = $PlayerCard/Name
@onready var turn_indicator_node: Sprite2D = $PlayerCard/TurnIndicator
@onready var cash_amount_node: RichTextLabel = $PlayerCard/CashAmount
@onready var folded_badge_node: Sprite2D = $PlayerCard/FoldBadge
@onready var winner_badge_node: Sprite2D = $PlayerCard/WinnerBadge
@onready var bet_badge_node: Sprite2D = $PlayerCard/BetBadge
@onready var card_back_1: Sprite2D = $PlayerCard/CardBack1
@onready var card_back_2: Sprite2D = $PlayerCard/CardBack2
@onready var game_manager: GameSceneManager = get_tree().root.get_node("Game/GameManager")

var card_front_1 = null
var card_front_2 = null

var peer_id = 0
var is_player_turn: bool = false
var hand_cash: int = 0
var is_folded: bool = false
var is_big_blind: bool = false
var is_small_blind: bool = false
var bet_value: int = 0
var show_cards: bool = false
var hole_cards: Array[CardData] = []
var is_winner: bool = false
var player_color: String = ""
var player_name: String = ""

func _ready() -> void:
	# Set player details
	if (player_color != ""):
		player_profile_picture_node.modulate = player_color
	player_name_label_node.text = "[font_size=16]%s[/font_size]" % player_name
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
			var bet_badge_text: RichTextLabel = bet_badge_node.get_node("Text")
			bet_badge_text.text = "SB"
		elif is_big_blind:
			bet_badge_node.visible = true
			var bet_badge_text: RichTextLabel = bet_badge_node.get_node("Text")
			bet_badge_text.text = "BB"
	elif (game_manager.game_state_data.game_state != GameState.State.PreHand):
		bet_badge_node.visible = true
		var bet_badge_text: RichTextLabel = bet_badge_node.get_node("Text")
		bet_badge_text.text = "$%s" % bet_value
	
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
			var card_instance: Card = card_scene.instantiate()
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
