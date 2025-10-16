extends Node

var debug_output_node = null

func log(text: String) -> void:
	#if (debug_output_node == null):
		#debug_output_node = get_tree().root.get_node("%s/DebugOutput" % get_tree().get_current_scene().name)
		
	if (debug_output_node != null):
		debug_output_node.text + "\n%s" % text
