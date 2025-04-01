@tool
extends Resource

class_name Stat

var cached_value := 0.0
var cached_max := 0.0

var enable_signal := true:
    set(value):
        enable_signal = value
        on_value_changed()

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
    if not enable_signal: return
    var current_value = get_value()
    var current_max = get_max()
    if cached_value != current_value or cached_max != current_max:
        value_changed.emit()
        cached_value = current_value
        cached_max = current_max

## Constructor
func _init(_base_value = 0.0, _clamped = true, _min_value = 0.0, _max_value = 100.0, _clamped_modifier = false, _flat_modifier = 0.0, _percent_modifier = 0.0, _max_percent_modifier = 0.0, _max_flat_modifier = 0.0) -> void:
    enable_signal = false
    self.clamped = _clamped
    self.clamped_modifier = _clamped_modifier
    self.base_value = _base_value
    self.min_value = _min_value
    self.max_value = _max_value
    self.percent_modifier = _percent_modifier
    self.flat_modifier = _flat_modifier
    self.max_percent_modifier = _max_percent_modifier
    self.max_flat_modifier = _max_flat_modifier
    enable_signal = true

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

func add_flat(amount: float) -> float:
    var old_val = flat_modifier
    flat_modifier += amount
    return flat_modifier - old_val

func add_percent(amount: float) -> float:
    var old_val = percent_modifier
    percent_modifier += amount
    return percent_modifier - old_val

func add_max_flat(amount: float) -> float:
    var old_val = max_flat_modifier
    max_flat_modifier += amount
    return max_flat_modifier - old_val

func add_max_percent(amount: float) -> float:
    var old_val = max_percent_modifier
    max_percent_modifier += amount
    return max_percent_modifier - old_val

func add_value(amount: float) -> float:
    var old_val = base_value
    base_value += amount
    return base_value - old_val

func add_max_value(amount: float) -> float:
    var old_val = max_value
    max_value += amount
    return max_value - old_val

## reset all modifiers
func reset_modifiers() -> void:
    enable_signal = false
    percent_modifier = 0.0
    flat_modifier = 0.0
    max_flat_modifier = 0.0
    max_percent_modifier = 0.0
    cached_value = 0.0
    cached_max = 0.0
    enable_signal = true

## Returns a string representation of the stat
func string() -> String:
    return "Value: %s (Base: %s, Flat: %s, Percent: %s%%)" % [
        get_value(), base_value, flat_modifier, percent_modifier
    ]

func to_dict() -> Dictionary:
    return {
        "base_value": base_value,
        "flat_modifier": flat_modifier,
        "percent_modifier": percent_modifier,
        "max_flat_modifier": max_flat_modifier,
        "max_percent_modifier": max_percent_modifier,
        "min_value": min_value,
        "max_value": max_value,
        "clamped_modifier": clamped_modifier,
        "clamped": clamped,
    }

func from_dict(dict: Dictionary) -> void:
    enable_signal = false
    max_value = dict.max_value
    min_value = dict.min_value
    base_value = dict.base_value
    flat_modifier = dict.flat_modifier
    percent_modifier = dict.percent_modifier
    max_flat_modifier = dict.max_flat_modifier
    max_percent_modifier = dict.max_percent_modifier    
    clamped_modifier = dict.clamped_modifier
    clamped = dict.clamped
    enable_signal = true