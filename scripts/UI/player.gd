extends Node2D
class_name Player

@onready var player_card_node = $PlayerCard
@onready var player_name_label_node = $PlayerCard/Name
@onready var turn_indicator_node = $PlayerCard/TurnIndicator
@onready var cash_amount_node = $PlayerCard/CashAmount
@onready var folded_badge_node = $PlayerCard/FoldBadge
@onready var bet_badge_node = $PlayerCard/BetBadge
@onready var game_manager = get_tree().root.get_node("Root/GameManager")

var player_id = 0
var is_player_turn: bool = false
var current_cash: int = 0
var is_folded: bool = false
var is_big_blind: bool = false
var is_small_blind: bool = false

func _ready() -> void:
	player_name_label_node.text = "[font_size=16][b]%s[/b][/font_size]" % [str(player_id)]
	cash_amount_node.text = "$" + str(current_cash)
	if is_player_turn:
		turn_indicator_node.visible = true
		
	# Badge logic, only want one
	if is_folded:
		player_card_node.set_modulate("aaaaaa")
		folded_badge_node.visible = true
	elif is_small_blind:
		bet_badge_node.visible = true
		bet_badge_node.get_node("Text").text = "SB"
	elif is_big_blind:
		bet_badge_node.visible = true
		bet_badge_node.get_node("Text").text = "BB"
