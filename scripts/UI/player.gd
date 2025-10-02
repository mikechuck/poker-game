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
	if is_folded:
		player_card_node.set_modulate("aaaaaa")
		folded_badge_node.visible = true
	if is_small_blind:
		bet_badge_node.visible = true
		bet_badge_node.get_node("Text").text = "SB"
	if is_big_blind:
		bet_badge_node.visible = true
		bet_badge_node.get_node("Text").text = "BB"
		
func _draw() -> void:
	pass

func toggle_show_folded(show: bool) -> void:
	is_folded = show
	if show:
		player_card_node.set_modulate("aaaaaa")
		folded_badge_node.visible = true
	else:
		player_card_node.set_modulate(Color.WHITE)
		folded_badge_node.visible = true
	
func toggle_show_big_blind(show: bool) -> void:
	is_big_blind = show
	if show:
		bet_badge_node.visible = true
		bet_badge_node.get_node("Text").text = "$" + str(game_manager.default_big_blind)
	else:
		bet_badge_node.visible = false
		
func toggle_show_small_blind(show: bool) -> void:
	is_small_blind = show
	if show:
		bet_badge_node.visible = true
		bet_badge_node.get_node("Text").text = "$" + str(game_manager.default_small_blind)
	else:
		bet_badge_node.visible = false
