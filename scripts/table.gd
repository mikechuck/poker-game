extends Node2D

var screen_origin


func _draw() -> void:
	screen_origin = get_viewport_rect().size / 2
	
	# draw the table
	var center = Vector2(screen_origin.x, screen_origin.y)
	var radius = 225
	var color = Color.WEB_GREEN
	draw_circle(center, radius, color)
	
	# Draw the table outline
	var colorOutline = Color.BLACK
	var widthOutline = 35  # The thickness of the outline
	draw_circle(center, radius, colorOutline, false, widthOutline)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	queue_redraw()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
