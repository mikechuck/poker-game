extends Node2D

@export var seat_select_button_scene: PackedScene = preload("res://scenes/UI/seat_button.tscn")

var poker_table_position
var screen_origin
var table_radius = 225
var player_seats: Dictionary[int, PlayerSeat]

func _ready() -> void:
	# Get reference to all the seats, save to array
	pass

func _draw() -> void:
	screen_origin = get_viewport_rect().size / 2

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func update_player_seats(player_seat_data: Dictionary[int, PlayerSeat]):
	player_seats = player_seat_data
	# Got new seat data, loop through seat nodes and enable/disable based on if player is there
	# Move player spawning logic to this script
	# Add some more data to the Player scene UI so 
	# Connect the seat button to "request seat" rpc call to server
	# Add a "connected players" list in the top corner to show everyone in the room
