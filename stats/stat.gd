@tool
extends Resource

class_name Stat

var cached_value := 0.0
var cached_max := 0.0

signal value_changed ## Emit when stat value changes

@export_category("Stat")
## Clamps the value to be between min_value and max_value
## Base value will be clamped between min_value and max_value
@export var clamped:bool:
    set(value):
        if clamped == value: return
        clamped = value
        var old_value = base_value
        if clamped: base_value = clamp(base_value, min_value, get_max())
        if old_value != base_value: on_value_changed()

## Base value
@export var base_value:float:
    set(value):
        if base_value == value: return
        if clamped: base_value = clamp(value, min_value, get_max())
        else: base_value = value
        on_value_changed()

## Min value
@export var min_value:float: 
    set(value):
        if min_value == value: return
        min_value = min(value, max_value)
        if clamped: base_value = clamp(base_value, min_value, get_max())
        on_value_changed()

## Max value
@export var max_value:float:
    set(value):
        if max_value == value: return
        max_value = max(value, min_value)
        if clamped: base_value = clamp(base_value, min_value, get_max())
        on_value_changed()

@export_group("Modifiers")
## Clamps the value to be between min_value and max_value,
## Base value is not affected it has no limit unless clamped is true
@export var clamped_modifier:bool:
    set(value):
        if clamped_modifier == value: return
        clamped_modifier = value
        on_value_changed()

## Percent modifier
@export var percent_modifier:float:
    set(value):
        if percent_modifier == value: return
        percent_modifier = value
        on_value_changed()

## Flat modifier
@export var flat_modifier:float:
    set(value):
        if flat_modifier == value: return
        flat_modifier = value
        on_value_changed()

## Max percent modifier
@export var max_percent_modifier:float:
    set(value):
        if max_percent_modifier == value: return
        max_percent_modifier = value
        if clamped: base_value = clamp(base_value, min_value, get_max())
        on_value_changed()

## Max flat modifier
@export var max_flat_modifier:float:
    set(value):
        if max_flat_modifier == value: return
        max_flat_modifier = value
        if clamped: base_value = clamp(base_value, min_value, get_max())
        on_value_changed()

## Emit when stat value changes
func on_value_changed() -> void:
    if cached_value != get_value() or cached_max != get_max():
        cached_value = get_value()
        cached_max = get_max()
        value_changed.emit()

## Constructor
func _init(_base_value = 0.0, _clamped = true, _min_value = 0.0, _max_value = 100.0, _clamped_modifier = false, _max_percent_modifier = 0.0, _max_flat_modifier = 0.0) -> void:
    self.clamped = _clamped
    self.clamped_modifier = _clamped_modifier
    self.base_value = _base_value
    self.min_value = _min_value
    self.max_value = _max_value
    self.max_percent_modifier = _max_percent_modifier
    self.max_flat_modifier = _max_flat_modifier

## Returns the calculated value of the stat and if it is clamped_modifier returns the clamped value
func get_value() -> float:
    if clamped_modifier:
        return clamp(base_value + ((percent_modifier / 100.0) * base_value) + flat_modifier, min_value, get_max())
    else: 
        return base_value + ((percent_modifier / 100.0) * base_value) + flat_modifier

## Returns the cached value
func get_cached_value() -> float:
    return cached_value

## Returns the cached max
func get_cached_max() -> float:
    return cached_max

## Returns a value from 0.0 to 1.0
func get_normalized_value() -> float:
    var max_val = get_max()
    if max_val == min_value: return 0.0
    return (get_value() - min_value) / (max_val - min_value)

## Returns the calculated max value
func get_max() -> float:
    return max_value + ((max_percent_modifier / 100.0) * max_value) + max_flat_modifier

## Returns the min value
func get_min() -> float:
    return min_value

## Returns the difference between the base value and the current value
func get_difference() -> float:
    return get_value() - base_value

## Returns the difference between the max value and the current value
func get_max_difference() -> float:
    return get_max() - max_value

## Returns a value from 0.0 to 1.0
func get_difference_fraction() -> float:
    return (get_value() - base_value) / base_value

## return true if the value is at max value and false otherwise
func is_max() -> bool:
    return get_value() == max_value

## return true if the value is at min value and false otherwise
func is_min() -> bool:
    return get_value() == min_value

## add value to a flat modifier
func add_flat(amount: float) -> void:
    flat_modifier += amount

## add value to a percent modifier
func add_percent(amount: float) -> void:
    percent_modifier += amount

## add value to the base value
func add_value(amount: float) -> void:
    base_value += amount

## reset all modifiers
func reset_modifiers() -> void:
    percent_modifier = 0.0
    flat_modifier = 0.0
    max_flat_modifier = 0.0
    max_percent_modifier = 0.0

## Returns a string representation of the stat
func string() -> String:
    return "Value: %s (Base: %s, Flat: %s, Percent: %s%%)" % [
        get_value(), base_value, flat_modifier, percent_modifier
    ]

# Clamping modifier values
