extends Node

#Note: this doesn't work, should fix this later at some point

func _ready() -> void:
	# Only run this if we are actually exported to the Web
	if OS.has_feature("web"):
		_setup_browser_paste_listener()

func _setup_browser_paste_listener() -> void:
	var paste_callback: JavaScriptObject = JavaScriptBridge.create_callback(_on_browser_paste)
	var window: Variant = JavaScriptBridge.get_interface("window")
	if window:
		@warning_ignore("unsafe_method_access")
		window.addEventListener("paste", paste_callback)

func _on_browser_paste(args: Array) -> void:
	var event: JavaScriptObject = args[0]
	
	@warning_ignore("unsafe_property_access")
	var clipboard_data: Variant = event.clipboardData
	
	if clipboard_data:
		# 1. Stop the browser's default behavior from confusing Godot's input loop
		@warning_ignore("unsafe_method_access")
		event.preventDefault()
		
		# 2. Extract the text directly from the system clipboard
		@warning_ignore("unsafe_method_access")
		var text: String = clipboard_data.getData("text")
		
		# 3. Synchronize it with the engine's cache
		DisplayServer.clipboard_set(text)
		
		# 4. Instantly insert it without waiting for an extra frame
		var focused_node: Control = get_viewport().gui_get_focus_owner()
		if focused_node is LineEdit:
			(focused_node as LineEdit).insert_text_at_caret(text)
		elif focused_node is TextEdit:
			(focused_node as TextEdit).insert_text_at_caret(text)
