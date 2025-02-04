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

var _ref_stat : Stat
var _applied_value := 0.0
var _stats : Array[Array]
var _expression : Expression

# splits a variable into it's parts, seperated by the "." character
# @param variable: variable to split
# @return: an array with 2 elements, the first is the name of the variable without the part that comes after the "." character and the second is the part that comes after the "." character
func _split_variable(variable: String) -> Array:
    var parts = variable.split(".")
    if parts.size() == 1:
        return [parts[0], ""]
    else:
        return [parts[0], parts[1]]

func _string_to_ref_stat_type(type: String) -> RefStatType:
    match type:
        "bvalue": return RefStatType.BASE_VALUE_MULTIPLY
        "value": return RefStatType.VALUE_MULTIPLY
        "bmax": return RefStatType.BASE_MAX_VALUE_MULTIPLY
        "max": return RefStatType.MAX_VALUE_MULTIPLY
        "min": return RefStatType.MIN_MULTIPLY
    return RefStatType.VALUE_MULTIPLY

func _extract_variables(expression: String) -> Array:
    var pattern = r"\b[a-zA-Z_]\w*(?:\.[a-zA-Z_]\w*)*\b"
    var regex = RegEx.new()
    regex.compile(pattern)
    
    var result = []
    var search_result = regex.search_all(expression)
    
    for match_result in search_result:
        result.append(match_result.get_string(0))
    
    return result

func _get_stats(parent: RefCounted, stats: Array) -> Array[Array]:
    var result: Array[Array] = []
    for stat in stats:
        var split = _split_variable(stat)
        result.append([parent.get_stat(split[0]), _string_to_ref_stat_type(split[1])])
    return result

func _get_stat_value(stats: Array) -> float:
    var type = stats[1]
    match type:
        RefStatType.BASE_VALUE_MULTIPLY:
            return stats[0].base_value
        RefStatType.VALUE_MULTIPLY:
            return stats[0].get_value()
        RefStatType.BASE_MAX_VALUE_MULTIPLY:
            return stats[0].max_value
        RefStatType.MAX_VALUE_MULTIPLY:
            return stats[0].get_max()
        RefStatType.MIN_MULTIPLY:
            return stats[0].get_min()
    return 0.0

func _evaluate_math_expression() -> float:
    if _math_expression == "" or _expression == null: return 0.0
    var stat_values = []
    for stat in _stats:
        stat_values.append(_get_stat_value(stat))
    stat_values.append(_value)
    var result = _expression.execute(stat_values)
    if _expression.has_execute_failed(): 
        push_error("Error in condition math expression :" + _expression.get_error_text())
        return 0.0
    if result is int or result is float:
        return float(result)
    return 0.0

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
    return 0.0

func _update_value() -> void:
    if not _snapshot_stats:
        update()

## initialize the stat
func init_stat(parent: Object) -> void:
    super.init_stat(parent)
    if parent == null or _ref_stat != null or _stats != null or _stats.size() > 0: return
    if _math_expression != "":
        var stat_names = _extract_variables(_math_expression)
        _stats = _get_stats(parent, stat_names)
        _expression = Expression.new()
        stat_names.append("value")
        _expression.parse(_math_expression, stat_names)
    if _ref_stat_name != "":
        _ref_stat = parent.get_stat(_ref_stat_name)		

## uninitialize the stat
func uninit_stat(_remove_all := false) -> void:
    super.uninit_stat(_remove_all)
    _stats.clear()
    _expression = null
    _disconnect_signals()
    _ref_stat = null

## check if the stat is valid
func is_valid() -> bool:
    return (super.is_valid() and _ref_stat != null) or _ref_stat_type == RefStatType.EXPRESSION

## check if the stat is equal to another stat
func is_equal(mod: StatModifier) -> bool:
    if not (mod is StatModifierComposite) or not super.is_equal(mod): return false
    if _ref_stat_name != mod._ref_stat_name: return false
    if _ref_stat_type != mod._ref_stat_type: return false
    if _snapshot_stats != mod._snapshot_stats: return false
    return true

func _connect_signals() -> void:
    if _snapshot_stats: return
    if _ref_stat != null and not _ref_stat.is_connected("value_changed", _update_value):
        _ref_stat.connect("value_changed", _update_value)
    for stat in _stats:
        if stat[0] != null and not stat[0].is_connected("value_changed", _update_value):
            stat[0].connect("value_changed", _update_value)

func _disconnect_signals() -> void:
    if _snapshot_stats: return
    if _ref_stat != null and _ref_stat.is_connected("value_changed", _update_value):
        _ref_stat.disconnect("value_changed", _update_value)
    for stat in _stats:
        if stat[0] != null and stat[0].is_connected("value_changed", _update_value):
            stat[0].disconnect("value_changed", _update_value)

## apply the stat
func apply(multiplier:int = 1) -> void:
    if not is_valid(): return
    if not can_apply(): return
    _connect_signals()
    var ref_value = _ref_value() * multiplier
    match _type:
        StatModifierType.FLAT:
            _stat.flat_modifier += ref_value
        StatModifierType.PERCENT:
            _stat.percent_modifier += ref_value
        StatModifierType.VALUE:
            _stat.base_value += ref_value
        StatModifierType.MAX_VALUE:
            _stat.max_value += ref_value
        StatModifierType.MAX_FLAT:
            _stat.max_flat_modifier += ref_value
        StatModifierType.MAX_PERCENT:
            _stat.max_percent_modifier += ref_value
    _applied_value += ref_value    
    _apply_count += 1 * multiplier

## remove the stat
func remove(_multiplier := 1) -> void:
    if not is_valid(): return
    if not is_applied(): return
    _disconnect_signals()
    match _type:
        StatModifierType.FLAT:
            _stat.flat_modifier -= _applied_value
        StatModifierType.PERCENT:
            _stat.percent_modifier -= _applied_value
        StatModifierType.VALUE:
            _stat.base_value -= _applied_value
        StatModifierType.MAX_VALUE:
            _stat.max_value -= _applied_value
        StatModifierType.MAX_FLAT:
            _stat.max_flat_modifier -= _applied_value
        StatModifierType.MAX_PERCENT:
            _stat.max_percent_modifier -= _applied_value
    _applied_value = 0.0
    _apply_count = 0
