extends Node2D

@export var player_scene: PackedScene = preload("res://scenes/player.tscn")
@export var seat_select_button_scene: PackedScene = preload("res://scenes/UI/seat_button.tscn")

var poker_table_position
var screen_origin
var table_radius = 225
var player_seats: Dictionary[int, PlayerSeat]
var seat_nodes: Dictionary[int, Node]

func _ready() -> void:
	var seats_in_group = get_tree().get_nodes_in_group("seats")
	for seat in seats_in_group:
		var seat_id = seat.seat_number
		seat_nodes[seat_id] = seat

func _draw() -> void:
	screen_origin = get_viewport_rect().size / 2

func update_player_seats(player_seat_data: Dictionary[int, PlayerSeat]):
	player_seats = player_seat_data
	for seat_id in player_seat_data.keys():
		var seat_data = player_seat_data[seat_id]
		var seat_node = seat_nodes[seat_id]
		print("seat position:", seat_node)
		if seat_data.player_id != 0:
			var player_instance = player_scene.instantiate()
			player_instance.position = seat_node.position
			player_instance.player_id = seat_data.player_id
			seat_data.player_node = player_instance
			add_child(player_instance)
			seat_nodes[seat_id].visible = false
		else:
			seat_nodes[seat_id].visible = true
	# Got new seat data, loop through seat nodes and enable/disable based on if player is there
	# Move player spawning logic to this script
	# Add some more data to the Player scene UI so 
	# Connect the seat button to "request seat" rpc call to server
	# Add a "connected players" list in the top corner to show everyone in the room
	
