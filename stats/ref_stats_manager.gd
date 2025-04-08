class_name RefStatManager
extends RefCounted

## Signal emitted when any reference stat is changed
signal ref_stats_changed

## Represents a single reference stat with its metadata
class RefStatEntry:
	var stat: Stat
	var type: int
	var path: String
	
	func _init(p_stat: Stat, p_type: int, p_path: String):
		stat = p_stat
		type = p_type
		path = p_path
	
	func get_value() -> float:
		if stat == null: return 0.0
		match type:
			0: return stat.base_value  # BASE_VALUE
			1: return stat.get_value() # VALUE
			2: return stat.max_value   # BASE_MAX_VALUE
			3: return stat.get_max()   # MAX_VALUE
			4: return stat.get_min()   # MIN_VALUE
			5: return stat.get_normalized_value()   # NORMALIZED_VALUE
		return 0.0

## Parent object that owns the stats
var _parent: Object
## Dictionary mapping stat names to RefStatEntry objects
var _ref_stats: Dictionary = {}
## Whether to snapshot stat values or track changes
var _dynamic_update: bool = false

## Initializes the manager
## [param parent]: The parent object containing the stats
## [param dynamic_update]: Whether to track stat changes dynamically
func _init(parent: Object = null, dynamic_update: bool = false) -> void:
	self._parent = parent
	self._dynamic_update = dynamic_update

## Sets whether to dynamically update when reference stats change
func set_dynamic_update(dynamic: bool) -> void:
	if _dynamic_update == dynamic:
		return
		
	_dynamic_update = dynamic
	if dynamic:
		_connect_all_signals()
	else:
		_disconnect_all_signals()

## Adds a reference stat by name and type
## [param stat_name]: Name of the stat to reference
## [param stat_type]: Type of value to extract from the stat
## [return]: True if the stat was added successfully
func add_ref_stat(stat_name: String, stat_type: int) -> bool:
	if _parent == null or not _parent.has_method("get_stat"):
		push_error("RefStatManager: Parent object is invalid or doesn't have get_stat method")
		return false
		
	if _ref_stats.has(stat_name):
		# Already tracking this stat
		return true
		
	var stat = _parent.get_stat(stat_name)
	if stat == null:
		push_warning("RefStatManager: Could not find stat named '%s'" % stat_name)
		return false
		
	var entry = RefStatEntry.new(stat, stat_type, stat_name)
	_ref_stats[stat_name] = entry
	
	if _dynamic_update:
		_connect_stat_signal(stat)
		
	return true

## Extracts reference stat names and types from an expression string
## [param expression]: Math expression with stat references (e.g., "health.value + armor.base")
## [return]: Array of stat reference entries [name, type]
func extract_ref_stats_from_expression(expression: String) -> Array:
	var pattern = r"\b([a-zA-Z_]\w*)\.([a-zA-Z_]\w*)\b"
	var regex = RegEx.new()
	regex.compile(pattern)
	
	var results = []
	var search_result = regex.search_all(expression)
	
	for match_result in search_result:
		var stat_name = match_result.get_string(1)
		var stat_type = match_result.get_string(2)
		results.append([stat_name, _string_to_stat_type(stat_type)])
	
	return results

## Adds multiple reference stats from a math expression
## [param expression]: Math expression with stat references
## [return]: Array of successfully added stat names
func add_ref_stats_from_expression(expression: String) -> Array:
	var stat_refs = extract_ref_stats_from_expression(expression)
	var added_stats = []
	
	for ref in stat_refs:
		if add_ref_stat(ref[0], ref[1]):
			added_stats.append(ref[0])
	
	return added_stats

## Gets the value of a reference stat
## [param stat_name]: Name of the reference stat
## [return]: The current value of the reference stat
func get_ref_stat_value(stat_name: String) -> float:
	if not _ref_stats.has(stat_name):
		push_warning("RefStatManager: Attempted to get value of unknown stat '%s'" % stat_name)
		return 0.0
		
	return _ref_stats[stat_name].get_value()

## Gets all reference stat values as a dictionary
## [return]: Dictionary mapping stat names to their current values
func get_all_ref_stat_values() -> Dictionary:
	var result = {}
	for stat_name in _ref_stats:
		result[stat_name] = _ref_stats[stat_name].get_value()
	return result

## Clears all reference stats
func clear() -> void:
	if _dynamic_update:
		_disconnect_all_signals()
	_ref_stats.clear()

## Converts a string stat type to an integer type
## [param type_str]: String representation of the stat type (e.g., "value", "base")
## [return]: Integer representation of the stat type
func _string_to_stat_type(type_str: String) -> int:
	match type_str:
		"base", "bvalue": return 0  # BASE_VALUE
		"value": return 1           # VALUE
		"bmax": return 2            # BASE_MAX_VALUE
		"max": return 3             # MAX_VALUE
		"min": return 4             # MIN_VALUE
	return 1  # Default to VALUE

## Called when a reference stat changes
func _on_stat_changed(_new_value, _new_max, _old_value, _old_max) -> void:
	ref_stats_changed.emit()

## Connects signals for all reference stats
func _connect_all_signals() -> void:
	if not _dynamic_update:
		return
		
	for stat_name in _ref_stats:
		_connect_stat_signal(_ref_stats[stat_name].stat)

## Disconnects signals for all reference stats
func _disconnect_all_signals() -> void:
	for stat_name in _ref_stats:
		_disconnect_stat_signal(_ref_stats[stat_name].stat)

## Connects signal for a single reference stat
func _connect_stat_signal(stat: Stat) -> void:
	if stat == null or stat.is_connected("value_changed", _on_stat_changed):
		return
		
	stat.connect("value_changed", _on_stat_changed)

## Disconnects signal for a single reference stat
func _disconnect_stat_signal(stat: Stat) -> void:
	if stat == null or not stat.is_connected("value_changed", _on_stat_changed):
		return
		
	stat.disconnect("value_changed", _on_stat_changed)