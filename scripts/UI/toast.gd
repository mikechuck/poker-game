extends PanelContainer
class_name Toast

@onready var message_node = $Message

func _ready() -> void:
	message_node.text = ""
	modulate.a = 0.0
	
func show_message(message: String) -> void:
	modulate.a = 0.0
	message_node.text = "[font_size=10]%s[/font_size]" % message
	
	# Animate in
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.05)
	
	# Wait then animate out
	await get_tree().create_timer(3).timeout
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.2)
	await fade_out.finished
	queue_free()
