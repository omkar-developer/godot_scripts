extends StatModifier

## composite stats modifier uses a math expression and a reference stat
class_name StatModifierComposite

enum RefStatType {
    BASE_VALUE_MULTIPLY, ## multiplies the base value of the stat
    VALUE_MULTIPLY, ## multiplies the value of the stat
    BASE_MAX_VALUE_MULTIPLY, ## multiplies the base max value of the stat
    MAX_VALUE_MULTIPLY, ## multiplies the max value of the stat
    MIN_MULTIPLY, ## multiplies the min value of the stat
    PERCENT_BASE_VALUE, ## multiplies the base value of the stat
    PERCENT_VALUE, ## multiplies the value of the stat
    PERCENT_MAX_VALUE, ## multiplies the max value of the stat
    EXPRESSION ## uses a math expression
}

## name of the stat to use as a reference
@export var _ref_stat_name := ""
## type of stat to use as a reference
@export var _ref_stat_type := RefStatType.BASE_VALUE_MULTIPLY
## snapshot the value of the reference stat if false modifier will be dynamically updated when ref stat changes
@export var _snapshot_stats := true
## math expression to calculate the value
## format of the variables: stat_name.type (types are: bvalue, value, bmax, max)
## value is the value
@export var _math_expression := ""

var _ref_stat_manager: RefStatManager = null
var _expression: Expression = null

## initialize the stat
func init_stat(parent: Object) -> bool:
    var result = super.init_stat(parent)
    if not result or parent == null:
        return result
    
    # Create the ref stat manager with dynamic update based on snapshot setting
    _ref_stat_manager = RefStatManager.new(parent, not _snapshot_stats)
    
    # Set up math expression if provided
    if _math_expression != "":
        _setup_expression()
    
    # Set up ref stat if provided
    if _ref_stat_name != "":
        _ref_stat_manager.add_ref_stat(_ref_stat_name, _ref_stat_type_to_manager_type(_ref_stat_type))
    
    # Connect to the ref stats changed signal
    if not _snapshot_stats:
        _ref_stat_manager.connect("ref_stats_changed", _on_ref_stats_changed)
    
    return result

## uninitialize the stat
func uninit_stat(remove_all := false) -> void:
    super.uninit_stat(remove_all)
    
    # Disconnect signal and clear manager
    if _ref_stat_manager != null:
        if not _snapshot_stats and _ref_stat_manager.is_connected("ref_stats_changed", _on_ref_stats_changed):
            _ref_stat_manager.disconnect("ref_stats_changed", _on_ref_stats_changed)
        _ref_stat_manager.clear()
        _ref_stat_manager = null
    
    _expression = null

## check if the stat is valid
func is_valid() -> bool:
    if not super.is_valid():
        return false
    
    # Expression-based modifier is valid if the expression is set up
    if _ref_stat_type == RefStatType.EXPRESSION:
        return _expression != null
    
    # Reference-based modifier is valid if the manager and ref stat exist
    return _ref_stat_manager != null and _ref_stat_manager.get_ref_stat_value(_ref_stat_name) != 0.0

## check if the stat is equal to another stat
func is_equal(mod: StatModifier) -> bool:
    if not (mod is StatModifierComposite) or not super.is_equal(mod):
        return false
        
    var other = mod as StatModifierComposite
    if _ref_stat_name != other._ref_stat_name:
        return false
    if _ref_stat_type != other._ref_stat_type:
        return false
    if _snapshot_stats != other._snapshot_stats:
        return false
    if _math_expression != other._math_expression:
        return false
        
    return true

func can_apply() -> bool:
    return not _is_applied or not _apply_only_once

## Called when reference stats change
func _on_ref_stats_changed() -> void:
    if not _is_applied:
        return
    
    # Remove and reapply to update with new referenced values
    remove(false)
    apply()

## Sets up the math expression
func _setup_expression() -> void:
    var stat_names = _ref_stat_manager.add_ref_stats_from_expression(_math_expression)
    
    # Prepare expression variables array for parsing
    var expr_vars = []
    for name in stat_names:
        expr_vars.append(name)
    expr_vars.append("value")  # Add value as the last variable
    
    # Create and parse the expression
    _expression = Expression.new()
    var parse_result = _expression.parse(_math_expression, expr_vars)
    if parse_result != OK:
        push_error("Error parsing expression '%s': %s" % [_math_expression, _expression.get_error_text()])
        _expression = null

## Calculates the reference value based on the type
func _ref_value() -> float:
    if _ref_stat_manager == null:
        return 0.0
    
    # Handle expression-based calculation
    if _ref_stat_type == RefStatType.EXPRESSION:
        return _evaluate_math_expression()
    
    # Handle reference stat-based calculation
    var ref_value = _ref_stat_manager.get_ref_stat_value(_ref_stat_name)
    
    match _ref_stat_type:
        RefStatType.BASE_VALUE_MULTIPLY, RefStatType.VALUE_MULTIPLY, RefStatType.BASE_MAX_VALUE_MULTIPLY, RefStatType.MAX_VALUE_MULTIPLY, RefStatType.MIN_MULTIPLY:
            return ref_value * _value
        RefStatType.PERCENT_BASE_VALUE, RefStatType.PERCENT_VALUE, RefStatType.PERCENT_MAX_VALUE:
            return ref_value * _value / 100.0
    
    return 0.0

## Evaluates the math expression
func _evaluate_math_expression() -> float:
    if _expression == null or _ref_stat_manager == null:
        return 0.0
    
    # Get all stat values
    var stat_values = []
    var all_values = _ref_stat_manager.get_all_ref_stat_values()
    for stat_name in all_values:
        stat_values.append(all_values[stat_name])
    
    # Add the modifier value as the last parameter
    stat_values.append(_value)
    
    # Execute the expression
    var result = _expression.execute(stat_values)
    if _expression.has_execute_failed():
        push_error("Error in math expression execution: %s" % _expression.get_error_text())
        return 0.0
    
    if result is int or result is float:
        return float(result)
    
    return 0.0

## Converts RefStatType to manager stat type
func _ref_stat_type_to_manager_type(ref_type: RefStatType) -> int:
    match ref_type:
        RefStatType.BASE_VALUE_MULTIPLY, RefStatType.PERCENT_BASE_VALUE:
            return 0  # BASE_VALUE
        RefStatType.VALUE_MULTIPLY, RefStatType.PERCENT_VALUE:
            return 1  # VALUE
        RefStatType.BASE_MAX_VALUE_MULTIPLY:
            return 2  # BASE_MAX_VALUE
        RefStatType.MAX_VALUE_MULTIPLY, RefStatType.PERCENT_MAX_VALUE:
            return 3  # MAX_VALUE
        RefStatType.MIN_MULTIPLY:
            return 4  # MIN_VALUE
    return 1  # Default to VALUE

## apply the stat
func apply() -> float:
    if not is_valid():
        return 0.0
    if not can_apply():
        return 0.0
    
    var ref_value = _ref_value()
    
    var actual_change = 0.0
    match _type:
        StatModifierType.FLAT:
            actual_change = _stat.add_flat(ref_value)
        StatModifierType.PERCENT:
            actual_change = _stat.add_percent(ref_value)
        StatModifierType.VALUE:
            actual_change = _stat.add_value(ref_value)
        StatModifierType.MAX_VALUE:
            actual_change = _stat.add_max_value(ref_value)
        StatModifierType.MAX_FLAT:
            actual_change = _stat.add_max_flat(ref_value)
        StatModifierType.MAX_PERCENT:
            actual_change = _stat.add_max_percent(ref_value)
        StatModifierType.MIN_VALUE:
            actual_change = _stat.add_min_value(ref_value)
    
    if actual_change != 0.0:
        _is_applied = true
        _applied_value += actual_change
    
    return actual_change

## remove the stat
func remove(remove_all := true) -> float:
    if not is_valid():
        return 0.0
    if not _is_applied:
        return 0.0
    
    var removal_amount = _applied_value
    if not remove_all and not _apply_only_once:
        removal_amount = _ref_value()
    
    var actual_change = 0.0
    match _type:
        StatModifierType.FLAT:
            actual_change = _stat.add_flat(-removal_amount)
        StatModifierType.PERCENT:
            actual_change = _stat.add_percent(-removal_amount)
        StatModifierType.VALUE:
            actual_change = _stat.add_value(-removal_amount)
        StatModifierType.MAX_VALUE:
            actual_change = _stat.add_max_value(-removal_amount)
        StatModifierType.MAX_FLAT:
            actual_change = _stat.add_max_flat(-removal_amount)
        StatModifierType.MAX_PERCENT:
            actual_change = _stat.add_max_percent(-removal_amount)
        StatModifierType.MIN_VALUE:
            actual_change = _stat.add_min_value(-removal_amount)
    
    _applied_value += actual_change  # Will subtract since actual_change is negative
    
    # Reset state if all effect is removed
    if remove_all or abs(_applied_value) <= 0.000001:
        _is_applied = false
        _applied_value = 0.0
    
    return actual_change