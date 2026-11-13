extends Control
class_name ConfirmationModal

#@export var confirmation_text: String = "":
	#set(value):
		#confirmation_text = value
		#_update_confirmation_text()
		
#signal modal_choice(is_confirmed)
@onready var message_node: RichTextLabel = $ContainerBounds/MarginContainer/VBoxContainer/Message
var modal_callback: Callable

func _ready() -> void:
	pass
	#message_node.text = "[font_size=18]%s[/font_size]" % confirmation_text
	
#func _update_confirmation_text() -> void:
	#message_node.text = "[font_size=18]%s[/font_size]" % confirmation_text

func _on_confirm_button_pressed() -> void:
	#emit_signal("modal_choice", true)
	modal_callback.call(true)
	visible = false

func _on_cancel_button_pressed() -> void:
	#emit_signal("modal_choice", false)
	modal_callback.call(false)
	visible = false
	
func pop_modal(message_text: String, callback_function: Callable):
	modal_callback = callback_function
	message_node.text = "[font_size=18]%s[/font_size]" % message_text
	visible = true
