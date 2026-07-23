extends RefCounted
class_name JSONEnumParser

static func convert(data) -> Variant:
	if data is Dictionary:
		var obj = RefCounted.new()
		for key: StringName in data:
			var val = type_convert(data[key], TYPE_PACKED_BYTE_ARRAY)
			obj.set(key, val)
			obj.set(key.to_lower().capitalize(), val)
	
	return data
