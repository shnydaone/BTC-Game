class_name Serial
extends RefCounted
## JSON-safe save and load for sim state objects.
##
## to_dict() walks an object's script variables. from_dict() writes them back, casting
## each value to the type of the variable's current value, because JSON parses every
## number as a float. Typed arrays of state classes are rebuilt element by element, and
## typed dictionaries get their values cast. Untyped containers must hold only floats
## and strings so a save and load round trip prints identically.


static func to_dict(obj: Object) -> Dictionary:
	var d: Dictionary = {}
	for p: Dictionary in obj.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			d[p["name"]] = _encode(obj.get(p["name"]))
	return d


static func from_dict(obj: Object, d: Dictionary) -> void:
	for p: Dictionary in obj.get_property_list():
		if not (p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var name: String = p["name"]
		if not d.has(name):
			push_error("Serial: save is missing %s" % name)
			continue
		var current: Variant = obj.get(name)
		match typeof(current):
			TYPE_OBJECT:
				from_dict(current, d[name])
			TYPE_ARRAY:
				_fill_array(current, d[name])
			TYPE_DICTIONARY:
				_fill_dictionary(current, d[name])
			_:
				obj.set(name, _cast(typeof(current), d[name]))


static func _encode(v: Variant) -> Variant:
	match typeof(v):
		TYPE_OBJECT:
			return to_dict(v)
		TYPE_ARRAY:
			return (v as Array).map(func(x: Variant) -> Variant: return _encode(x))
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k: Variant in v:
				out[k] = _encode(v[k])
			return out
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			return Array(v)
	return v


static func _cast(type: int, v: Variant) -> Variant:
	match type:
		TYPE_INT:
			return int(v)
		TYPE_FLOAT:
			return float(v)
		TYPE_BOOL:
			return bool(v)
		TYPE_STRING:
			return String(v)
		TYPE_PACKED_STRING_ARRAY:
			return PackedStringArray(v)
		TYPE_PACKED_INT64_ARRAY:
			var ints := PackedInt64Array()
			for x: Variant in v:
				ints.append(int(x))
			return ints
		TYPE_PACKED_FLOAT64_ARRAY:
			return PackedFloat64Array(v)
	return v


static func _fill_array(target: Array, source: Array) -> void:
	target.clear()
	var script: Script = target.get_typed_script()
	for x: Variant in source:
		if script != null:
			var item: Object = script.new()
			from_dict(item, x)
			target.append(item)
		else:
			target.append(_cast(target.get_typed_builtin(), x))


static func _fill_dictionary(target: Dictionary, source: Dictionary) -> void:
	target.clear()
	for k: Variant in source:
		target[k] = _cast(target.get_typed_value_builtin(), source[k])
