extends Line2D

var screen_origin

var height
var segments

func _draw() -> void:
	screen_origin = get_viewport_rect().size / 2
	
	# Clear any existing points
	clear_points()

	var radius_x = width / 2.0
	var radius_y = height / 2.0
	# Use the 'Closed' property to connect the start and end points
	self.closed = true

	# Loop through the desired number of segments
	for i in range(segments):
		var angle = deg_to_rad(360.0 * i / segments)
		var x = radius_x * cos(angle)
		var y = radius_y * sin(angle)
		add_point(Vector2(x, y))
	
	# draw the table
	#var center = Vector2(screen_origin.x, screen_origin.y)
	#var radius = 225
	#var color = Color.WEB_GREEN
	#draw_circle(center, radius, color)
	
	# Draw the table outline
	#var colorOutline = Color.BLACK
	#var widthOutline = 35  # The thickness of the outline
	#draw_circle(center, radius, colorOutline, false, widthOutline)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	queue_redraw()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
