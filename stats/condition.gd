extends Resource

## Condition resource for evaluating conditions based on stat values.[br]
## if ref_stat1_name is not set, the condition will use the value property for comparison.[br]
## if ref_stat2_name is not set, the condition will use the value property for comparison.[br]
## if both ref_stat1_name and ref_stat2_name are not set, the condition will always return false.
class_name Condition
# TODO: Add support for multiple reference stats

## Emitted when the condition's result changes (true/false).[br]
## [param condition]: The new result of the condition.
signal condition_changed(condition: bool)

## Defines the type of comparison for the condition.
enum ConditionType {
	EQUAL,
	GREATER_THAN,
	LESS_THAN,
	GREATER_THAN_EQUAL,
	LESS_THAN_EQUAL,
	NOT_EQUAL,
	MATH_EXPRESSION
}

## Defines the type of stat to use for comparison.
enum RefStatType {
	BASE_VALUE,          ## The base value of the stat.
	VALUE,               ## The current value of the stat.
	MAX_VALUE,           ## The maximum value of the stat.
	BASE_MAX_VALUE,      ## The base maximum value of the stat.
	MIN,                 ## The minimum value of the stat.
	PERCENT,             ## The normalized value of the stat as a percentage.
	NORMALIZED_PERCENT    ## The normalized value of the stat (0.0 to 1.0).
}

## Name of the first reference stat.
@export var _ref_stat1_name: String
## Name of the second reference stat.
@export var _ref_stat2_name: String
## Type of the first reference stat.
@export var _ref_stat1_type: RefStatType = RefStatType.VALUE
## Type of the second reference stat.
@export var _ref_stat2_type: RefStatType = RefStatType.VALUE
## The type of comparison to evaluate.
@export var _condition_type: ConditionType = ConditionType.EQUAL
## Whether to negate the condition's result.
@export var _negation: bool = false
## Value to compare against if reference stats are null or unused.
@export var _value: float = 0.0
## Cooldown time (in seconds) between condition evaluations.
@export var cooldown: float = 0.0
## Math expression for advanced condition logic. [br]
## Used when `ConditionType` is `MATH_EXPRESSION`.
@export var _math_expression: String = ""

## Reference to the first stat.
var _ref_stat1: Stat
## Reference to the second stat.
var _ref_stat2: Stat
## Current state of the condition (true/false).
@export_storage var _current_condition: bool = false
## Timer for managing cooldown.
@export_storage var _timer := 0.0
## Parsed math expression (used with `ConditionType.MATH_EXPRESSION`).
var _expression: Expression = null

## Returns the current state of the condition (true/false). [br]
## [return]: The current state of the condition.
func get_condition() -> bool:
	return _current_condition

## Retrieves the value of a given stat based on the specified type.[br]
## [param stat]: The stat to retrieve the value from. [br]
## [param _type]: The type of value to retrieve (e.g., VALUE, MAX_VALUE). [br]
## [param default_value]: The fallback value if the stat is null. [br]
## [return]: The requested stat value or the default value.
func _get_stat_value(stat: Stat, _type := RefStatType.VALUE, default_value := 0.0) -> float:
	if stat == null: return default_value
	if _type == RefStatType.BASE_VALUE: return stat.base_value
	if _type == RefStatType.VALUE: return stat.get_value()
	if _type == RefStatType.MAX_VALUE: return stat.get_max()
	if _type == RefStatType.BASE_MAX_VALUE: return stat.max_value
	if _type == RefStatType.MIN: return stat.get_min()
	if _type == RefStatType.PERCENT: return stat.get_normalized_value() * 100
	if _type == RefStatType.NORMALIZED_PERCENT: return stat.get_normalized_value()
	return default_value

## Evaluates the condition based on the reference stats, value, and condition type.[br]
## [return]: True if the condition is met, false otherwise.
func _evaluate_condition() -> bool:
	if _ref_stat1 == null and _ref_stat2 == null:
		push_error("Condition must have at least one reference stat.")
		return false
	var val1 = _get_stat_value(_ref_stat1, _ref_stat1_type, _value)
	var val2 = _get_stat_value(_ref_stat2, _ref_stat2_type, _value)
	var result = false
	if _condition_type == ConditionType.EQUAL:
		result = val1 == val2
	elif _condition_type == ConditionType.GREATER_THAN:
		result = val1 > val2
	elif _condition_type == ConditionType.LESS_THAN:
		result = val1 < val2
	elif _condition_type == ConditionType.GREATER_THAN_EQUAL:
		result = val1 >= val2
	elif _condition_type == ConditionType.LESS_THAN_EQUAL:
		result = val1 <= val2
	elif _condition_type == ConditionType.NOT_EQUAL:
		result = val1 != val2
	elif _condition_type == ConditionType.MATH_EXPRESSION:
		if _expression == null:
			push_error("Condition math expression is not set.")
			return false
		var res = _expression.execute([val1, val2])
		if _expression.has_execute_failed():
			push_error("Error in condition math expression: " + _expression.get_error_text())
		if res is bool: result = res
	return not result if _negation else result

## Updates the condition state, checking if the result has changed.[br]
## [param _check_timer]: Whether to consider the cooldown timer.
func _update(_check_timer := true) -> void:
	if _check_timer and _timer > 0.0: return
	if _check_timer and cooldown > 0.0 and _timer <= 0.0:
		_timer = cooldown
		return
	var condition_result = _evaluate_condition()
	if condition_result != _current_condition:        
		_current_condition = condition_result
		condition_changed.emit(_current_condition)

func _on_value_change_update(_new_value, _new_max, _old_value, _old_max) -> void:
	_update()

## Establishes signal connections for the reference stats.
func _make_connections() -> void:
	if _ref_stat1 != null and not _ref_stat1.is_connected("value_changed", _on_value_change_update):
		_ref_stat1.connect("value_changed", _on_value_change_update)
	if _ref_stat2 != null and not _ref_stat2.is_connected("value_changed", _on_value_change_update):
		_ref_stat2.connect("value_changed", _on_value_change_update)

## Removes signal connections for the reference stats.
func _remove_connections() -> void:
	if _ref_stat1 != null and _ref_stat1.is_connected("value_changed", _on_value_change_update):
		_ref_stat1.disconnect("value_changed", _on_value_change_update)
	if _ref_stat2 != null and _ref_stat2.is_connected("value_changed", _on_value_change_update):
		_ref_stat2.disconnect("value_changed", _on_value_change_update)

## Initializes the condition with the given parent object.[br]
## [param parent]: The parent object to retrieve stats from.
func init_stat(parent: Object) -> void:
	if parent == null or !parent.has_method("get_stat"): return
	if _ref_stat1 != null or _ref_stat2 != null: return
	_ref_stat1 = parent.get_stat(_ref_stat1_name)
	_ref_stat2 = parent.get_stat(_ref_stat2_name)
	_make_connections()
	if _condition_type == ConditionType.MATH_EXPRESSION and _math_expression != "":
		_expression = Expression.new()
		if _expression.parse(_math_expression, ["value1", "value2"]) != OK:
			push_error("Error parsing condition math expression: " + _math_expression)
	_current_condition = _evaluate_condition()
	condition_changed.emit(_current_condition)

## Cleans up connections and resets internal state.
func uninit_stat() -> void:
	_remove_connections()
	_ref_stat1 = null
	_ref_stat2 = null
	_expression = null

## Checks if the condition is valid based on the current state of the reference stats.
func is_valid() -> bool:
	# Check if reference stats are set
	if _ref_stat1 == null and _ref_stat2 == null:
		push_error("Both reference stats are not set.")
		return false
	
	if not _ref_stat1_name.is_empty() and _ref_stat1 == null:
		push_error("Reference stat 1 is not set.")
		return false
	
	if not _ref_stat2_name.is_empty() and _ref_stat2 == null:
		push_error("Reference stat 2 is not set.")
		return false

	if _ref_stat1 != null and not _ref_stat1.is_connected("value_changed", _on_value_change_update):
		push_error("Signal connection for reference stat 1 is not established correctly.")
		return false
	if _ref_stat2 != null and not _ref_stat2.is_connected("value_changed", _on_value_change_update):
		push_error("Signal connection for reference stat 2 is not established correctly.")
		return false

	# If all checks pass
	return true

## Updates the condition based on the delta time (for cooldowns).[br]
## [param delta]: The time elapsed since the last frame.
func _process(delta: float) -> void:
	if _timer <= 0.0: return
	_timer -= delta
	if _timer <= 0.0:
		_update(false)

## Serializes the condition into a dictionary for saving.[br]
## [return]: A dictionary representing the condition's state.
func to_dict() -> Dictionary:
	return {
		"ref_stat1_name": _ref_stat1_name,
		"ref_stat2_name": _ref_stat2_name,
		"ref_stat1_type": _ref_stat1_type,
		"ref_stat2_type": _ref_stat2_type,
		"condition_type": _condition_type,
		"negation": _negation,
		"value": _value,
		"cooldown": cooldown,
		"math_expression": _math_expression,
		"current_condition": _current_condition,
		"timer": _timer
	}

## Deserializes the condition from a dictionary.[br]
## [param data]: A dictionary containing the condition's state.
func from_dict(data: Dictionary):
	_ref_stat1_name = data.get("ref_stat1_name", "")
	_ref_stat2_name = data.get("ref_stat2_name", "")
	_ref_stat1_type = data.get("ref_stat1_type", RefStatType.VALUE)
	_ref_stat2_type = data.get("ref_stat2_type", RefStatType.VALUE)
	_condition_type = data.get("condition_type", ConditionType.EQUAL)
	_negation = data.get("negation", false)
	_value = data.get("value", 0.0)
	cooldown = data.get("cooldown", 0.0)
	_math_expression = data.get("math_expression", "")
	_current_condition = data.get("current_condition", false)
	_timer = data.get("timer", 0.0)

## Returns the class name of this condition.
func get_class_name() -> String:
	return "Condition"
