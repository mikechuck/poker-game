extends Node2D

var screen_origin
var table_radius = 225
var single_angle = PI / 4; # 8 players, each at pi / 4 on the table radius

func _draw() -> void:
	screen_origin = get_viewport_rect().size / 2
	
	# draw the table
	var center = Vector2(screen_origin.x, screen_origin.y)
	var color = Color.WEB_GREEN
	draw_circle(center, table_radius, color)
	
	# Draw the table outline
	var colorOutline = Color.BLACK
	var widthOutline = 10  # The thickness of the outline
	draw_circle(center, table_radius, colorOutline, false, widthOutline)
	
	var playerColor = Color(1.0, 1.0, 1.0, 0.5) 
	for i in 8:
		var xPos = (table_radius + 60) * cos(i * single_angle) + screen_origin.x
		var yPos = (table_radius + 60) * sin(i * single_angle) + screen_origin.y
		var pos = Vector2(xPos, yPos)
		draw_circle(pos, 30, playerColor)
		var label = Label.new()
		label.position.x = pos.x - 6
		label.position.y = pos.y - 15
		label.text = str(i + 1)
		label.add_theme_font_size_override("font_size", 22)
		add_child(label)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	queue_redraw()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
