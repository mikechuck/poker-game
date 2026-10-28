extends Node

func get_engine_enum_name(enum_class_name: String, enum_value: int) -> String:
	for enum_name in ClassDB.class_get_enum_list(enum_class_name):
		var constants: PackedStringArray = ClassDB.class_get_enum_constants(enum_class_name, enum_name)
		
		for constant in constants:
			if ClassDB.class_get_integer_constant(enum_class_name, constant) == enum_value:
				return constant
				
	return "Unknown"
