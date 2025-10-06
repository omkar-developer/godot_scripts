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
## Dictionary mapping stat reference keys to RefStatEntry objects
var _ref_stats: Dictionary = {}
## Whether to snapshot stat values or track changes
var _dynamic_update: bool = false

# Store the parsed expression
var _current_expression: Expression = null
var _current_expression_string: String = ""

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

## Creates an expression-friendly variable name for a stat reference
## [param stat_name]: Name of the stat
## [param stat_type]: Type of the stat reference
## [return]: A variable name usable in Godot expressions
func create_expression_var_name(stat_name: String, stat_type: int) -> String:
	return "%s__%d" % [stat_name, stat_type]

## Converts an expression with stat references to a Godot-compatible expression
## [param expression]: Expression with stat references (e.g., "health:base + armor:value")
## [return]: Expression with Godot-compatible variable names
func convert_to_godot_expression(expression: String) -> String:
	var pattern = r"([a-zA-Z_]\w*)(?::([a-zA-Z_]\w*))?"
	var regex = RegEx.new()
	regex.compile(pattern)
	
	var result = expression
	var matches = regex.search_all(expression)
	
	for match_result in matches:
		var full_match = match_result.get_string()
		var stat_name = match_result.get_string(1)
		var stat_type_str = match_result.get_string(2)
		
		if stat_type_str.is_empty():
			stat_type_str = "value"  # Default to value if no type specified
			
		var stat_type = _string_to_stat_type(stat_type_str)
		var expr_var_name = create_expression_var_name(stat_name, stat_type)
		
		# Replace the original reference with the expression-compatible variable name
		result = result.replace(full_match, expr_var_name)
	
	return result

## Sets the current expression for later evaluation
## [param expression_str]: Math expression with stat references
## [return]: True if the expression was successfully parsed
func set_expression(expression_str: String) -> bool:
	if not _current_expression_string.is_empty() and expression_str != _current_expression_string:
		clear()
	# First make sure all referenced stats are added
	var stat_names = add_ref_stats_from_expression(expression_str)
	
	# Convert expression to Godot-compatible format
	var godot_expr_str = convert_to_godot_expression(expression_str)
	
	# Create and parse the expression
	var expression = Expression.new()
	var error = expression.parse(godot_expr_str, stat_names)
	if error != OK:
		push_error("RefStatManager: Failed to parse expression: %s (error code %d)" % [godot_expr_str, error])
		return false
	
	# Store the parsed expression for future evaluations
	_current_expression = expression
	_current_expression_string = expression_str
	return true

## Evaluates the current expression using current stat values
## [return]: The result of evaluating the expression, or null if evaluation failed
func evaluate_current_expression() -> Variant:
	if _current_expression == null:
		push_error("RefStatManager: No expression has been set")
		return null
	
	# Build variable list for evaluation
	var variables = []
	for ref_key in _ref_stats:
		var entry = _ref_stats[ref_key]
		variables.append(entry.get_value())
	
	# Evaluate the expression with the variable values
	var result = _current_expression.execute(variables)
	if _current_expression.has_execute_failed():
		push_error("RefStatManager: Failed to execute expression: %s" % _current_expression_string)
		return null
		
	return result

## Convenience method to set and immediately evaluate an expression
## [param expression_str]: Math expression with stat references
## [return]: The result of evaluating the expression, or null if evaluation failed
func evaluate_expression(expression_str: String) -> Variant:
	if _current_expression_string == expression_str:
		return evaluate_current_expression()
	if not set_expression(expression_str):
		return null
	return evaluate_current_expression()

## Adds a reference stat by name and type
## [param stat_name]: Name of the stat to reference
## [param stat_type]: Type of value to extract from the stat
## [return]: True if the stat was added successfully
func add_ref_stat(stat_name: String, stat_type: int) -> bool:
	if _parent == null:
		push_error("RefStatManager: Parent object is invalid")
		return false
	
	var ref_key = create_expression_var_name(stat_name, stat_type)
	if _ref_stats.has(ref_key):
		# Already tracking this stat with this type
		return true
		
	var normalized_name = stat_name.to_snake_case()
	var stat = _parent.get(normalized_name) as Stat
	if stat == null:
		push_warning("RefStatManager: Could not find stat named '%s'" % stat_name)
		return false
		
	var entry = RefStatEntry.new(stat, stat_type, stat_name)
	_ref_stats[ref_key] = entry
	
	if _dynamic_update:
		_connect_stat_signal(stat)
		
	return true

## Extracts reference stat names and types from an expression string
## [param expression]: Math expression with stat references (e.g., "health.value + armor.base")
## [return]: Array of stat reference entries [name, type]
func extract_ref_stats_from_expression(expression: String) -> Array:
	var pattern = r"\b([a-zA-Z_]\w*)(?::([a-zA-Z_]\w*))?\b"
	var regex = RegEx.new()
	regex.compile(pattern)
	
	var results = []
	var search_result = regex.search_all(expression)
	
	for match_result in search_result:
		var stat_name = match_result.get_string(1)
		# Check if a type was provided, otherwise default to "base"
		var stat_type = match_result.get_string(2)
		if stat_type== "":
			stat_type = "value"
		results.append([stat_name, _string_to_stat_type(stat_type)])
	
	return results

## Adds multiple reference stats from a math expression
## [param expression]: Math expression with stat references
## [return]: Array of successfully added stat references in the format "name:type"
func add_ref_stats_from_expression(expression: String) -> Array:
	var stat_refs = extract_ref_stats_from_expression(expression)
	var added_stats = []
	
	for ref in stat_refs:
		if add_ref_stat(ref[0], ref[1]):
			added_stats.append(create_expression_var_name(ref[0], ref[1]))
	
	return added_stats

## Gets the value of a reference stat
## [param stat_name]: Name of the reference stat
## [param stat_type]: Type of the reference stat
## [return]: The current value of the reference stat
func get_ref_stat_value(stat_name: String, stat_type: int = 1) -> float:
	var ref_key = create_expression_var_name(stat_name, stat_type)
	if not _ref_stats.has(ref_key):
		push_warning("RefStatManager: Attempted to get value of unknown stat reference '%s'" % ref_key)
		return 0.0
		
	return _ref_stats[ref_key].get_value()

## Gets all reference stat values as a dictionary
## [return]: Dictionary mapping stat reference keys to their current values
func get_all_ref_stat_values() -> Dictionary:
	var result = {}
	for ref_key in _ref_stats:
		result[ref_key] = _ref_stats[ref_key].get_value()
	return result

## Gets a dictionary of values for a specific stat across all its registered types
## [param stat_name]: Name of the stat
## [return]: Dictionary mapping stat types to their current values
func get_stat_values_by_type(stat_name: String) -> Dictionary:
	var result = {}
	for ref_key in _ref_stats.keys():
		var entry = _ref_stats[ref_key]
		if entry.path == stat_name:
			result[entry.type] = entry.get_value()
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
		"normalized": return 5      # NORMALIZED_VALUE
	return 1  # Default to VALUE

## Called when a reference stat changes
func _on_stat_changed(_new_value, _new_max, _old_value, _old_max) -> void:
	ref_stats_changed.emit()

## Connects signals for all reference stats
func _connect_all_signals() -> void:
	if not _dynamic_update:
		return
	
	# Use a set to ensure we only connect each unique stat once
	var connected_stats = {}
	
	for ref_key in _ref_stats:
		var stat = _ref_stats[ref_key].stat
		if stat != null and not connected_stats.has(stat):
			_connect_stat_signal(stat)
			connected_stats[stat] = true

## Disconnects signals for all reference stats
func _disconnect_all_signals() -> void:
	# Use a set to ensure we only disconnect each unique stat once
	var disconnected_stats = {}
	
	for ref_key in _ref_stats:
		var stat = _ref_stats[ref_key].stat
		if stat != null and not disconnected_stats.has(stat):
			_disconnect_stat_signal(stat)
			disconnected_stats[stat] = true

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
