class_name JSONEnumParser
extends RefCounted

static func convert(data) -> Variant:
	if data is Dictionary:
		var obj = RefCounted.new()
		for key in data:
			var val = convert(data[key], TYPE_PACKED_BYTE_ARRAY)
			obj.set(key, val)
			obj.set(key.to_lower().capitalize(), val)
	
	return data
