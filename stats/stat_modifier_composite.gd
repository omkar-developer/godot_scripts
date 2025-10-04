@tool
extends StatModifier

## StatModifierComposite allows stats to be modified based on other reference stats.
## This creates dynamic relationships between different stats in the game.
class_name StatModifierComposite

## Types of reference stat calculations that can be performed
enum RefStatType {
	BASE_VALUE_MULTIPLY, ## Multiplies the base value of the reference stat by the modifier value
	VALUE_MULTIPLY, ## Multiplies the current value of the reference stat by the modifier value
	BASE_MAX_VALUE_MULTIPLY, ## Multiplies the base max value of the reference stat by the modifier value
	MAX_VALUE_MULTIPLY, ## Multiplies the current max value of the reference stat by the modifier value
	MIN_MULTIPLY, ## Multiplies the current min value of the reference stat by the modifier value
	PERCENT_BASE_VALUE, ## Takes a percentage (modifier value) of the reference stat's base value
	PERCENT_VALUE, ## Takes a percentage (modifier value) of the reference stat's current value
	PERCENT_MAX_VALUE, ## Takes a percentage (modifier value) of the reference stat's max value
	BASE_VALUE_ADD, ## Adds the modifier value to the current value of the reference stat
	VALUE_ADD, ## Adds the modifier value to the base value of the reference stat
	MAX_VALUE_ADD, ## Adds the modifier value to the max value of the reference stat
	MIN_ADD, ## Adds the modifier value to the min value of the reference stat
	DIMINISHING_RETURNS, ## Applies diminishing returns effect to the reference stat's value
	EXPRESSION ## Uses a custom math expression to calculate the value
}

## Name of the stat to use as a reference for calculations
@export var _ref_stat_name := ""

## Type of calculation to perform with the reference stat
@export var _ref_stat_type := RefStatType.BASE_VALUE_MULTIPLY

## When true, captures reference stat values once; when false, dynamically updates when reference stat changes
@export var _snapshot_stats := true:
	set(value):
		_snapshot_stats = value
		_apply_only_once = not value

## Math expression used when _ref_stat_type is EXPRESSION
## Variables format: stat_name:type (types are: base/bvalue, value, bmax, max, min, normalized)
@export var _math_expression := ""

## Reference to the stat being used for calculations
var _ref_stat : Stat

## Manager for handling multiple reference stats in expressions
var _ref_stat_manager : RefStatManager = null

## Calculates the value based on the reference stat according to the selected type
func _ref_value() -> float:
	if _ref_stat_type == RefStatType.EXPRESSION:
		return _evaluate_math_expression()
	if _ref_stat == null: return 0.0
	match _ref_stat_type:
		RefStatType.BASE_VALUE_MULTIPLY:
			return _ref_stat.base_value * _value
		RefStatType.VALUE_MULTIPLY:
			return _ref_stat.get_value() * _value
		RefStatType.BASE_MAX_VALUE_MULTIPLY:
			return _ref_stat.max_value * _value
		RefStatType.MAX_VALUE_MULTIPLY:
			return _ref_stat.get_max() * _value
		RefStatType.MIN_MULTIPLY:
			return _ref_stat.get_min() * _value
		RefStatType.PERCENT_BASE_VALUE:
			return _ref_stat.base_value * _value / 100.0
		RefStatType.PERCENT_VALUE:
			return _ref_stat.get_value() * _value / 100.0
		RefStatType.PERCENT_MAX_VALUE:
			return _ref_stat.get_max() * _value / 100.0
		RefStatType.BASE_VALUE_ADD:
			return _ref_stat.base_value + _value
		RefStatType.VALUE_ADD:
			return _ref_stat.get_value() + _value
		RefStatType.MAX_VALUE_ADD:
			return _ref_stat.get_max() + _value
		RefStatType.MIN_ADD:
			return _ref_stat.get_min() + _value
		RefStatType.DIMINISHING_RETURNS:
			return 1 - (1 / (1 + _ref_stat.get_value() * _value * 0.01))
	return 0.0

## Evaluates the math expression using the RefStatManager
## [return]: The result of the expression evaluation or 0 if expression is invalid
func _evaluate_math_expression() -> float:
	if _math_expression == "" or _ref_stat_manager == null: 
		return 0.0
	
	# Use the RefStatManager to evaluate the expression
	var result = _ref_stat_manager.evaluate_expression(_math_expression)
	
	# If the expression failed to evaluate, return 0
	if result == null:
		return 0.0
	
	# Ensure result is a number
	if result is int or result is float:
		return float(result) * _value  # Apply our value as a multiplier
	
	return 0.0

## Updates the modifier value when reference stats change (for dynamic mode)
func _update_value(_new_value, _new_max, _old_value, _old_max) -> void:
	if not _snapshot_stats:
		# For dynamic updates, we need to remove and reapply the modifier
		if is_applied():
			remove()
			apply()

## Initializes the stat modifier with reference to the parent object's stats
## [param parent]: The object containing the stats
## [return]: True if initialization was successful, false otherwise
func init_stat(parent: Object) -> bool:
	var result = super.init_stat(parent)
	if not result or parent == null or _ref_stat != null: 
		return false
	
	# Initialize the reference stat manager
	_ref_stat_manager = RefStatManager.new(parent, !_snapshot_stats)
	
	# If using expression mode, set up the expression
	if _math_expression != "":
		# Add all stats from the expression
		_ref_stat_manager.add_ref_stats_from_expression(_math_expression)
		# Set the expression
		_ref_stat_manager.set_expression(_math_expression)
		
		# Connect signal for dynamic updates if needed
		if !_snapshot_stats:
			_ref_stat_manager.connect("ref_stats_changed", _update_value.bind(0.0, 0.0, 0.0, 0.0))
	
	# Set up reference stat if specified
	if _ref_stat_name != "":
		_ref_stat = parent.get_stat(_ref_stat_name)
		
		# Connect signal for dynamic updates if needed
		if !_snapshot_stats and _ref_stat != null:
			_ref_stat.connect("value_changed", _update_value)
	
	return true

## Cleans up references and disconnects signals
## [param _remove_all]: Whether to remove all applied effects
func uninit_stat(_remove_all := true) -> void:
	super.uninit_stat(_remove_all)
	
	# Clean up reference stat connection
	if _ref_stat != null and !_snapshot_stats and _ref_stat.is_connected("value_changed", _update_value):
		_ref_stat.disconnect("value_changed", _update_value)
	_ref_stat = null
	
	# Clean up reference stat manager
	if _ref_stat_manager != null:
		if !_snapshot_stats and _ref_stat_manager.is_connected("ref_stats_changed", _update_value):
			_ref_stat_manager.disconnect("ref_stats_changed", _update_value)
		_ref_stat_manager.clear()
		_ref_stat_manager = null

## Checks if the modifier has valid references
## [return]: True if the modifier has valid references and can be applied
func is_valid() -> bool:
	return (super.is_valid() and _ref_stat != null) or (_ref_stat_type == RefStatType.EXPRESSION and _ref_stat_manager != null)

## Compares with another modifier to check if they are functionally identical
## [param mod]: The modifier to compare with
## [return]: True if the modifiers are equal
func is_equal(mod: StatModifier) -> bool:
	if not (mod is StatModifierComposite) or not super.is_equal(mod): return false
	if _ref_stat_name != mod._ref_stat_name: return false
	if _ref_stat_type != mod._ref_stat_type: return false
	if _snapshot_stats != mod._snapshot_stats: return false
	if _math_expression != mod._math_expression: return false
	return true

## Applies the modifier to the target stat
## [return]: The actual change applied to the stat
func apply(_apply_value:float = 0.0) -> float:
	if not is_valid(): return 0.0
	var ref_value = _ref_value()
	return super.apply(ref_value)

## Simulates the effect of applying this modifier without changing the actual stat
## [return]: A dictionary containing predicted changes to the stat
func simulate_effect() -> Dictionary:
	if not is_valid():
		push_warning("Cannot simulate effect with an invalid composite modifier")
		return {}

	# Create a temporary copy of the stat
	var temp_stat = _stat.duplicate(true)
	
	# Apply the calculated reference value to the temp stat
	_apply_stat_modifier(_type, temp_stat, _ref_value())
	
	# Get the difference between original and modified stats
	return _stat.get_difference_from(temp_stat)

## Returns a dictionary representation of this modifier
## [return]: Dictionary containing all relevant modifier properties
func to_dict() -> Dictionary:
	var base_dict = super.to_dict()
	base_dict["ref_stat_name"] = _ref_stat_name
	base_dict["ref_stat_type"] = _ref_stat_type
	base_dict["snapshot_stats"] = _snapshot_stats
	base_dict["math_expression"] = _math_expression
	base_dict["class"] = "StatModifierComposite"
	return base_dict

## Loads this modifier from a dictionary
## [param dict]: Dictionary containing modifier properties
func from_dict(dict: Dictionary) -> void:
	super.from_dict(dict)
	if dict.has("ref_stat_name"): _ref_stat_name = dict["ref_stat_name"]
	if dict.has("ref_stat_type"): _ref_stat_type = dict["ref_stat_type"]
	if dict.has("snapshot_stats"): _snapshot_stats = dict["snapshot_stats"]
	if dict.has("math_expression"): _math_expression = dict["math_expression"]

## Print debug values
func _to_string() -> String:
	var ref_type_str = RefStatType.keys()[_ref_stat_type] if _ref_stat_type < RefStatType.size() else "Unknown"
	var base_info = super._to_string()
	
	var ref_info = " (RefStat: %s, Type: %s" % [_ref_stat_name, ref_type_str]
	
	if _ref_stat_type == RefStatType.EXPRESSION:
		ref_info += ", Expr: %s" % _math_expression.substr(0, 20)
		if _math_expression.length() > 20:
			ref_info += "..."
	
	ref_info += ", Dynamic: %s)" % (!_snapshot_stats)
	
	return base_info + ref_info
