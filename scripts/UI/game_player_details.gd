extends Control
class_name GamePlayerDetails

@onready var color_node = $PlayerColor
@onready var host_indicator_node = $PlayerColor/HostIndicator
@onready var name_node = $NameContainer/Name
@onready var spectator_icon_node = $Status/Spectator

func set_player_details(player_info: ConnectedPlayer):
	# We might not have all the data due to the initial game state data load request from game manager at startup
	if (player_info.player_color != ""):
		color_node.modulate = player_info.player_color
	name_node.text = "[font_size=10]%s[/font_size]" % player_info.player_name
	
	if (player_info.is_host):
		host_indicator_node.visible = true
	else:
		host_indicator_node.visible = false
	
	if (player_info.is_spectating):
		spectator_icon_node.visible = true
	else:
		spectator_icon_node.visible = false
