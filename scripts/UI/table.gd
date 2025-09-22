extends Node2D

@export var seat_select_button_scene: PackedScene = preload("res://scenes/UI/seat_button.tscn")

var poker_table_position
var screen_origin
var table_radius = 225
var player_seats: Dictionary[int, PlayerSeat]

func _draw() -> void:
	screen_origin = get_viewport_rect().size / 2
	if (poker_table_position):
		self.position = screen_origin - (poker_table_position / 2)
		
	var seat_color = Color(1.0, 1.0, 1.0, 0.5)
	var player_color = Color(1.0, 0.0, 0.0)
	for seat_index in player_seats.keys():
		var seat = player_seats[seat_index]
		var new_seat_pos =  Vector2(seat.pos.x + screen_origin.x, seat.pos.y + screen_origin.y)
		if (seat.player_id == 0):
			#draw_circle(new_seat_pos, 30, seat_color)
			var seat_select_button_instance = seat_select_button_scene.instantiate()
			var seat_center = seat_select_button_instance.button_node.position
			seat_select_button_instance.position = new_seat_pos - seat_center
			add_child(seat_select_button_instance)
			var label = Label.new()
			label.position.x = new_seat_pos.x - 6
			label.position.y = new_seat_pos.y - 15
			label.text = str(seat_index + 1)
			label.add_theme_font_size_override("font_size", 22)
			add_child(label)
		
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var poker_table_position = $PokerTable
	queue_redraw()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func update_player_seats(player_seat_data: Dictionary[int, PlayerSeat]):
	player_seats = player_seat_data
	queue_redraw()
