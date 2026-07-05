extends Node

var Enums: RefCounted

func _ready() -> void:
	load_json_enums("res://enums.json")
	
func load_json_enums(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		Log.message("Cannot load enums.json file, file does not exist")
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	var raw_dict = JSON.parse_string(json_string)
	
	if raw_dict == null:
		Log.error("Failed to parse enums json")
		return
		
	Enums.JSONEnumParser.convert(raw_dict)
	file.close()
