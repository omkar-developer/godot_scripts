extends Resource

## Class for managing _stat modifications.
class_name StatModifier

## Enum defining types of _stat modifications.
enum StatModifierType {
    FLAT, ## Flat modifier
    PERCENT, ## Percent modifier
    VALUE, ## Value modifier
    MAX_VALUE, ## Max value modifier
    MAX_FLAT, ## Max flat modifier
    MAX_PERCENT ## Max percent modifier
}

## Name of the _stat this modifier affects.
@export var _stat_name: String

## Type of the modification (e.g., FLAT, PERCENT, etc.).
@export var _type: StatModifierType

## The value of the modification to apply.
@export var _value: float

## The maximum number of times this modifier can be applied.[br]
## A value of -1 means it can be applied indefinitely.
@export var max_apply_count: int = -1

## The _stat instance this modifier is linked to.
var _stat: Stat

## Tracks how many times the modifier has been applied.
var _apply_count := 0

## Initializes the modifier with the provided _stat name, type, and value.
func _init(stat_name: String = "", type: StatModifierType = StatModifierType.FLAT, value: float = 0.0, _max_apply_count: int = -1) -> void:
    self._stat_name = stat_name
    self._type = type
    self._value = value
    self.max_apply_count = _max_apply_count

## Initializes the _stat reference by fetching it from the provided _parent.[br]
## [param _parent]: The node to fetch the _stat from.
func init_stat(_parent: RefCounted) -> void:
    if _parent == null or _stat != null: return
    _stat = _parent.get_stat(_stat_name)

## Clears the _stat reference to uninitialize the modifier.
func uninit_stat(_remove_all: bool = true) -> void:
    if _remove_all: remove_all()
    _stat = null

## Merges another modifier into this one by adding its value to this modifier's value.[br]
## [param mod]: The modifier to merge.
func merge(mod: StatModifier) -> void:
    set_value(_value + mod._value)

## Checks if another modifier is equivalent to this one (same type and _stat name).[br]
## [param mod]: The modifier to compare.[br]
## [return]: True if the modifiers are equal, false otherwise.
func is_equal(mod: StatModifier) -> bool:
    return _type == mod._type and _stat_name == mod._stat_name

## Checks if the modifier is valid (i.e., linked to a _stat).[br]
## [return]: True if the modifier has a valid _stat reference, false otherwise.
func is_valid() -> bool:
    return _stat != null

## Checks if the modifier is currently applied to the _stat.[br]
## [return]: True if the modifier is applied, false otherwise.
func is_applied(multiplier := 1) -> bool:
    return _apply_count >= multiplier

## Checks if the modifier can be applied (based on max_apply_count).[br]
## [return]: True if the modifier can be applied, false otherwise.
func can_apply(multiplier := 1) -> bool:
    return max_apply_count <= -1 or _apply_count + multiplier <= max_apply_count

func update() -> void:
    var old_count = _apply_count
    remove_all()
    apply(old_count)

## Sets the value of the modifier.
## [param _value]: The value to set.
func set_value(value: float = 0.0) -> void:
    var old_count = _apply_count
    remove_all()
    self._value = value
    apply(old_count)

## Sets the type of the modifier.
## [param _type]: The type to set.
func set_type(type: StatModifierType = StatModifierType.FLAT) -> void:
    var old_count = _apply_count
    remove_all()
    self._type = type
    apply(old_count)

## Applies the modifier to the _stat if it's valid and can be applied.
func apply(multiplier := 1) -> void:
    if not is_valid(): return
    if not can_apply(multiplier): return
    match _type:
        StatModifierType.FLAT:
            _stat.flat_modifier += _value * multiplier
        StatModifierType.PERCENT:
            _stat.percent_modifier += _value * multiplier
        StatModifierType.VALUE:
            _stat.base_value += _value * multiplier
        StatModifierType.MAX_VALUE:
            _stat.max_value += _value * multiplier
        StatModifierType.MAX_FLAT:
            _stat.max_flat_modifier += _value * multiplier
        StatModifierType.MAX_PERCENT:
            _stat.max_percent_modifier += _value * multiplier
    _apply_count += (1 * multiplier)

## Removes the modifier from the _stat if it's valid and currently applied.
func remove(multiplier := 1) -> void:
    if not is_valid(): return
    if not is_applied(multiplier): return
    match _type:
        StatModifierType.FLAT:
            _stat.flat_modifier -= _value * multiplier
        StatModifierType.PERCENT:
            _stat.percent_modifier -= _value * multiplier
        StatModifierType.VALUE:
            _stat.base_value -= _value * multiplier
        StatModifierType.MAX_VALUE:
            _stat.max_value -= _value * multiplier
        StatModifierType.MAX_FLAT:
            _stat.max_flat_modifier -= _value * multiplier
        StatModifierType.MAX_PERCENT:
            _stat.max_percent_modifier -= _value * multiplier
    _apply_count -= (1 * multiplier)

## Removes all applied modifiers from the _stat.
func remove_all() -> void:
    remove(_apply_count)

## Returns the name of the _stat this modifier affects.
func get_stat_name() -> String:
    return _stat_name

## Returns the type of the modifier.
func get_type() -> StatModifierType:
    return _type

## Returns the value of the modifier.
func get_value() -> float:
    return _value

## Returns the number of times this modifier has been applied.
func get_apply_count() -> int:
    return _apply_count