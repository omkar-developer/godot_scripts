extends Resource

## Class for managing stat modifications.
class_name StatModifier

## Enum defining types of stat modifications.
## Keep this as enum for inspector compatibility
enum StatModifierType {
    FLAT, ## Flat modifier
    PERCENT, ## Percent modifier
    VALUE, ## Value modifier
    MAX_VALUE, ## Max value modifier
    MAX_FLAT, ## Max flat modifier
    MAX_PERCENT ## Max percent modifier
}

## Name of the stat this modifier affects.
@export var _stat_name: String

## Type of the modification (e.g., FLAT, PERCENT, etc.).
@export var _type: StatModifierType

## The value of the modification to apply.
@export var _value: float

## Whether this modifier should only be applied once.
@export var _apply_only_once := true

## The stat instance this modifier is linked to.
var _stat: Stat

## Is this modifier currently applied
var _is_applied := false
var _applied_value := 0.0

## Initializes the modifier with the provided stat name, type, and value.
func _init(stat_name: String = "", type: StatModifierType = StatModifierType.FLAT, value: float = 0.0) -> void:
    self._stat_name = stat_name
    self._type = type
    self._value = value

## Initializes the stat reference by fetching it from the provided parent.
## [param parent]: The node to fetch the stat from.
func init_stat(parent: Object) -> void:
    if parent == null:
        push_error("Cannot initialize stat with null parent")
        return
        
    if _stat != null: 
        return
        
    if not parent.has_method("get_stat"):
        push_error("Parent object doesn't have get_stat method")
        return
        
    _stat = parent.get_stat(_stat_name)
    
    if _stat == null:
        push_warning("Could not find stat named '%s' in parent" % _stat_name)

## Clears the stat reference to uninitialize the modifier.
func uninit_stat() -> void:
    if _is_applied: remove()
    _stat = null

## Merges another modifier into this one by adding its value to this modifier's value.
## [param mod]: The modifier to merge.
## [return]: Whether the merge was successful.
func merge(mod: StatModifier) -> bool:
    if mod == null:
        return false
        
    if _type != mod._type or _stat_name != mod._stat_name:
        push_warning("Attempting to merge modifiers of different types or stats")
        return false
        
    set_value(_value + mod._value)
    return true

## Checks if another modifier is equivalent to this one (same type and stat name).
## [param mod]: The modifier to compare.
## [return]: True if the modifiers are equal, false otherwise.
func is_equal(mod: StatModifier) -> bool:
    return _type == mod._type and _stat_name == mod._stat_name

## Checks if the modifier is valid (i.e., linked to a stat).
## [return]: True if the modifier has a valid stat reference, false otherwise.
func is_valid() -> bool:
    return _stat != null

## Checks if the modifier is currently applied to the stat.
## [return]: True if the modifier is applied, false otherwise.
func is_applied() -> bool:
    return _is_applied

## Sets the value of the modifier.
## [param value]: The value to set.
func set_value(value: float = 0.0) -> void:
    if _is_applied and _apply_only_once:
        remove()
        self._value = value
        apply()
    else:
        self._value = value

## Sets the type of the modifier.
## [param type]: The type to set.
func set_type(type: StatModifierType = StatModifierType.FLAT) -> void:
    if _is_applied and _apply_only_once:
        remove()
        self._type = type
        apply()
    else:
        self._type = type

## Applies the modifier to the stat and returns the actual amount applied
func apply() -> float:
    if not is_valid(): return 0.0
    if _is_applied and _apply_only_once: return 0.0  # Prevent double application
    
    var actual_change = 0.0
    match _type:
        StatModifierType.FLAT:
            actual_change = _stat.add_flat(_value)
        StatModifierType.PERCENT:
            actual_change = _stat.add_percent(_value)
        StatModifierType.MAX_FLAT:
            actual_change = _stat.add_max_flat(_value)
        StatModifierType.MAX_PERCENT:
            actual_change = _stat.add_max_percent(_value)
        StatModifierType.VALUE:
            actual_change = _stat.add_value(_value)
        StatModifierType.MAX_VALUE:
            actual_change = _stat.add_max_value(_value)

    _is_applied = true
    _applied_value = actual_change
    return actual_change

## Removes the modifier from the stat and returns the actual amount removed
func remove() -> float:
    if not _apply_only_once: return 0.0
    if not is_valid(): return 0.0
    if not _is_applied: return 0.0
    
    var actual_change = 0.0
    match _type:
        StatModifierType.FLAT:
            actual_change = _stat.add_flat(-_applied_value)
        StatModifierType.PERCENT:
            actual_change = _stat.add_percent(-_applied_value)
        StatModifierType.MAX_FLAT:
            actual_change = _stat.add_max_flat(-_applied_value)
        StatModifierType.MAX_PERCENT:
            actual_change = _stat.add_max_percent(-_applied_value)
        StatModifierType.VALUE:
            actual_change = _stat.add_value(-_applied_value)
        StatModifierType.MAX_VALUE:
            actual_change = _stat.add_max_value(-_applied_value)

    _is_applied = false
    return -actual_change  # Return positive value for amount removed

## Returns the name of the stat this modifier affects.
func get_stat_name() -> String:
    return _stat_name

## Returns the type of the modifier.
func get_type() -> StatModifierType:
    return _type

## Returns the value of the modifier.
func get_value() -> float:
    return _value

## Print debug values
func _to_string() -> String:
    var applied_text = "not applied"
    if _is_applied:
        applied_text = "applied"
        
    return "StatModifier: %s %s %.2f (%s)" % [
        _stat_name, 
        StatModifierType.keys()[_type], 
        _value,
        applied_text
    ]

## Returns a duplicate copy of this modifier.
func copy() -> StatModifier:
    return duplicate(true)

## Returns a dictionary representation of this modifier.
func to_dict() -> Dictionary:
    return {
        "stat_name": _stat_name,
        "type": _type,
        "value": _value,
        "is_applied": _is_applied,
        "apply_only_once": _apply_only_once
    }

## Loads this modifier from a dictionary.
func from_dict(dict: Dictionary) -> void:
    if dict.has("stat_name"): _stat_name = dict["stat_name"]
    if dict.has("type"): _type = dict["type"]
    if dict.has("value"): _value = dict["value"]
    if dict.has("is_applied"): _is_applied = dict["is_applied"]
    if dict.has("apply_only_once"): _apply_only_once = dict["apply_only_once"]