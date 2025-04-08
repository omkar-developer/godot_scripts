@tool
extends Resource
## Represents a flexible and configurable stat system with support for clamping, modifiers, and serialization.
##
## This class provides a comprehensive stat management system, allowing for base values, flat and percent modifiers,
## and maximum/minimum constraints. It supports clamping for both base and final values, ensuring stat integrity.
## The class also emits signals when values change and includes utility functions for normalization, difference
## calculation, and boolean representation. Additionally, it supports serialization to and from dictionaries for easy
## saving and loading of stat configurations.

#TODO: check cached at node init
class_name Stat

## Epsilon value for floating point comparisons
const EPSILON = 0.0001

## Defines the data type of the stat
enum StatType {
	FLOAT,  ## Floating point value (default)
	INT,    ## Integer value
	BOOL    ## Boolean value (true/false)
}

## Cached value of the stat
var cached_value := 0.0

## Cached maximum value of the stat
var cached_max := 0.0

## Whether signals are enabled for value changes
var enable_signal := true:
	set(value):
		enable_signal = value
		on_value_changed()

## Emitted when the stat value changes
## [param new_value]: The new calculated value.
## [param new_max]: The new maximum value.
## [param old_value]: The previous calculated value.
## [param old_max]: The previous maximum value.
signal value_changed(new_value, new_max, old_value, old_max)

## Internal flag to temporarily disable signals
var _enable_signal := true

## Updates the base value, ensuring it adheres to clamping rules
func _update_base_value():
	if base_value_clamped: base_value = clamp(base_value, min_value, get_max())

func get_typed_value(raw_value: float) -> float:
	match stat_type:
		StatType.INT: return float(int(raw_value))
		StatType.BOOL: return 1.0 if raw_value > EPSILON else 0.0
		_: return raw_value  # FLOAT

@export_category("Stat")

## Clamps the base value to be between [param min_value] and [param max_value].
@export var base_value_clamped:bool:
	set(value):
		if base_value_clamped == value: return
		base_value_clamped = value
		_enable_signal = false
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Base value of the stat.
@export var base_value:float:
	set(value):
		if base_value == value: return
		base_value = value
		_enable_signal = false
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Minimum value the stat can have.
@export var min_value:float: 
	set(value):
		if min_value == value: return
		min_value = value
		_enable_signal = false
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Maximum value the stat can have.
@export var max_value:float:
	set(value):
		if max_value == value: return
		max_value = value
		_enable_signal = false
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## The type of the stat
@export var stat_type: StatType = StatType.FLOAT:
	set(value):
		if stat_type == value: return
		stat_type = value
		on_value_changed()

## Whether or not the stat is frozen. When frozen, cant change values.
@export var frozen: bool = false

@export_group("Modifiers")

## Clamps the final value to be between [param min_value] and [param max_value].
## Does not affect the base value.
@export var final_value_clamped:bool:
	set(value):
		if final_value_clamped == value: return
		final_value_clamped = value
		on_value_changed()

## Percent modifier applied to the base value.
@export var percent_modifier:float:
	set(value):
		if percent_modifier == value: return
		percent_modifier = value
		_enable_signal = false
		if percent_modifier_clamped: percent_modifier = clamp(percent_modifier, percent_modifier_min, percent_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Flat modifier added to the base value.
@export var flat_modifier:float:
	set(value):
		if flat_modifier == value: return
		flat_modifier = value
		_enable_signal = false
		if flat_modifier_clamped: flat_modifier = clamp(flat_modifier, flat_modifier_min, flat_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Percent modifier applied to the maximum value.
@export var max_percent_modifier:float:
	set(value):
		if max_percent_modifier == value: return
		max_percent_modifier = value
		_enable_signal = false
		if max_percent_modifier_clamped: max_percent_modifier = clamp(max_percent_modifier, max_percent_modifier_min, max_percent_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Flat modifier added to the maximum value.
@export var max_flat_modifier:float:
	set(value):
		if max_flat_modifier == value: return
		max_flat_modifier = value
		_enable_signal = false
		if max_flat_modifier_clamped: max_flat_modifier = clamp(max_flat_modifier, max_flat_modifier_min, max_flat_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

@export_category("Clamping")

## Clamps the flat modifier to be between [param flat_modifier_min] and [param flat_modifier_max].
@export var flat_modifier_clamped:bool = false:
	set(value):
		if flat_modifier_clamped == value: return
		flat_modifier_clamped = value
		_enable_signal = false
		if flat_modifier_clamped: flat_modifier = clamp(flat_modifier, flat_modifier_min, flat_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Minimum value for the flat modifier.
@export var flat_modifier_min:float:
	set(value):
		if flat_modifier_min == value: return
		flat_modifier_min = value
		_enable_signal = false
		if flat_modifier_clamped: flat_modifier = clamp(flat_modifier, flat_modifier_min, flat_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Maximum value for the flat modifier.
@export var flat_modifier_max:float:
	set(value):
		if flat_modifier_max == value: return
		flat_modifier_max = value
		_enable_signal = false
		if flat_modifier_clamped: flat_modifier = clamp(flat_modifier, flat_modifier_min, flat_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Clamps the percent modifier to be between [param percent_modifier_min] and [param percent_modifier_max].
@export var percent_modifier_clamped:bool = false:
	set(value):
		if percent_modifier_clamped == value: return
		percent_modifier_clamped = value
		_enable_signal = false
		if percent_modifier_clamped: percent_modifier = clamp(percent_modifier, percent_modifier_min, percent_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Minimum value for the percent modifier.
@export var percent_modifier_min:float:
	set(value):
		if percent_modifier_min == value: return
		percent_modifier_min = value
		_enable_signal = false
		if percent_modifier_clamped: percent_modifier = clamp(percent_modifier, percent_modifier_min, percent_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Maximum value for the percent modifier.
@export var percent_modifier_max:float:
	set(value):
		if percent_modifier_max == value: return
		percent_modifier_max = value
		_enable_signal = false
		if percent_modifier_clamped: percent_modifier = clamp(percent_modifier, percent_modifier_min, percent_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Clamps the max percent modifier to be between [param max_percent_modifier_min] and [param max_percent_modifier_max].
@export var max_percent_modifier_clamped:bool = false:
	set(value):
		if max_percent_modifier_clamped == value: return
		max_percent_modifier_clamped = value
		_enable_signal = false
		if max_percent_modifier_clamped: max_percent_modifier = clamp(max_percent_modifier, max_percent_modifier_min, max_percent_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Minimum value for the max percent modifier.
@export var max_percent_modifier_min:float:
	set(value):
		if max_percent_modifier_min == value: return
		max_percent_modifier_min = value
		_enable_signal = false
		if max_percent_modifier_clamped: max_percent_modifier = clamp(max_percent_modifier, max_percent_modifier_min, max_percent_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Maximum value for the max percent modifier.
@export var max_percent_modifier_max:float:
	set(value):
		if max_percent_modifier_max == value: return
		max_percent_modifier_max = value
		_enable_signal = false
		if max_percent_modifier_clamped: max_percent_modifier = clamp(max_percent_modifier, max_percent_modifier_min, max_percent_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Clamps the max flat modifier to be between [param max_flat_modifier_min] and [param max_flat_modifier_max].
@export var max_flat_modifier_clamped:bool = false:
	set(value):
		if max_flat_modifier_clamped == value: return
		max_flat_modifier_clamped = value
		_enable_signal = false
		if max_flat_modifier_clamped: max_flat_modifier = clamp(max_flat_modifier, max_flat_modifier_min, max_flat_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Minimum value for the max flat modifier.
@export var max_flat_modifier_min:float:
	set(value):
		if max_flat_modifier_min == value: return
		max_flat_modifier_min = value
		_enable_signal = false
		if max_flat_modifier_clamped: max_flat_modifier = clamp(max_flat_modifier, max_flat_modifier_min, max_flat_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Maximum value for the max flat modifier.
@export var max_flat_modifier_max:float:
	set(value):
		if max_flat_modifier_max == value: return
		max_flat_modifier_max = value
		_enable_signal = false
		if max_flat_modifier_clamped: max_flat_modifier = clamp(max_flat_modifier, max_flat_modifier_min, max_flat_modifier_max)
		_update_base_value()
		_enable_signal = true
		on_value_changed()

## Emits the [signal value_changed] signal when the stat value changes.
func on_value_changed() -> void:
	if not _enable_signal or not enable_signal: return
	var current_value = get_value()
	var current_max = get_max()
	if cached_value != current_value or cached_max != current_max:
		value_changed.emit(current_value, current_max, cached_value, cached_max)
		cached_value = current_value
		cached_max = current_max

## Constructor for initializing the stat.
## [param _base_value]: Initial base value (default: 0.0).
## [param _base_value_clamped]: Whether the base value is clamped (default: true).
## [param _min_value]: Minimum value (default: 0.0).
## [param _max_value]: Maximum value (default: 100.0).
## [param _final_value_clamped]: Whether the final value is clamped (default: false).
## [param _flat_modifier]: Initial flat modifier (default: 0.0).
## [param _percent_modifier]: Initial percent modifier (default: 0.0).
## [param _max_percent_modifier]: Initial max percent modifier (default: 0.0).
## [param _max_flat_modifier]: Initial max flat modifier (default: 0.0).
func _init(_base_value = 0.0, _base_value_clamped = false, _min_value = 0.0, _max_value = 100.0, _final_value_clamped = false, _flat_modifier = 0.0, _percent_modifier = 0.0, _max_percent_modifier = 0.0, _max_flat_modifier = 0.0) -> void:
	_enable_signal = false
	self.base_value_clamped = _base_value_clamped
	self.final_value_clamped = _final_value_clamped
	self.base_value = _base_value
	self.min_value = _min_value
	self.max_value = _max_value
	self.percent_modifier = _percent_modifier
	self.flat_modifier = _flat_modifier
	self.max_percent_modifier = _max_percent_modifier
	self.max_flat_modifier = _max_flat_modifier
	_enable_signal = true

## Returns the calculated value of the stat.
## If [param final_value_clamped] is true, returns the clamped value.
func get_value() -> float:
	var raw_value
	if final_value_clamped:
		raw_value = clamp(base_value + ((percent_modifier / 100.0) * base_value) + flat_modifier, min_value, get_max())
	else: 
		raw_value = base_value + ((percent_modifier / 100.0) * base_value) + flat_modifier
	
	# Apply type conversion before returning
	return get_typed_value(raw_value)

## Returns the cached value.
func get_cached_value() -> float:
	return cached_value

## Returns the cached maximum value.
func get_cached_max() -> float:
	return cached_max

## Returns a normalized value between 0.0 and 1.0.
func get_normalized_value() -> float:
	var max_val = get_max()
	if max_val == min_value: return 0.0
	return (get_value() - min_value) / (max_val - min_value)

## Returns the calculated maximum value.
func get_max() -> float:
	var raw_value = max_value + ((max_percent_modifier / 100.0) * max_value) + max_flat_modifier
	# Apply type conversion before returning
	return get_typed_value(raw_value)

## Returns the minimum value.
func get_min() -> float:
	return get_typed_value(min_value)

## Returns the difference between the base value and the current value.
func get_difference() -> float:
	return get_value() - base_value

## Returns the difference between the maximum value and the current value.
func get_max_difference() -> float:
	return get_max() - max_value

## Returns the fractional difference between the base value and the current value.
func get_difference_fraction() -> float:
	if base_value == 0.0: return 0.0
	return (get_value() - base_value) / base_value

## Returns true if the value is at the maximum value, false otherwise.
func is_max() -> bool:
	if stat_type == StatType.FLOAT:
		# Use epsilon comparison for floating point values
		return abs(get_value() - get_max()) < EPSILON  # Adjust epsilon as needed
	else:
		# For INT and BOOL, direct comparison is fine
		return get_value() == get_max()

## Returns true if the value is at the minimum value, false otherwise.
func is_min() -> bool:
	if stat_type == StatType.FLOAT:
		# Use epsilon comparison for floating point values 
		return abs(get_value() - min_value) < EPSILON  # Adjust epsilon as needed
	else:
		# For INT and BOOL, direct comparison is fine
		return get_value() == min_value

## Adds a flat amount to the flat modifier.
func add_flat(amount: float) -> float:
	if frozen: return 0.0
	var old_val = flat_modifier
	flat_modifier += get_typed_value(amount)
	return flat_modifier - old_val

## Adds a percentage amount to the percent modifier.
func add_percent(amount: float) -> float:
	if frozen: return 0.0
	var old_val = percent_modifier
	percent_modifier += amount
	return percent_modifier - old_val

## Adds a flat amount to the max flat modifier.
func add_max_flat(amount: float) -> float:
	if frozen: return 0.0
	var old_val = max_flat_modifier
	max_flat_modifier += get_typed_value(amount)
	return max_flat_modifier - old_val

## Adds a percentage amount to the max percent modifier.
func add_max_percent(amount: float) -> float:
	if frozen: return 0.0
	var old_val = max_percent_modifier
	max_percent_modifier += amount
	return max_percent_modifier - old_val

## Adds an amount to the base value.
func add_value(amount: float) -> float:
	if frozen: return 0.0
	var old_val = base_value
	base_value += get_typed_value(amount)
	return base_value - old_val

## Adds an amount to the maximum value.
func add_max_value(amount: float) -> float:
	if frozen: return 0.0
	var old_val = max_value
	max_value += get_typed_value(amount)
	return max_value - old_val

## Adds an amount to the minimum value.
func add_min_value(amount: float) -> float:
	if frozen: return 0.0
	var old_val = min_value
	min_value += get_typed_value(amount)
	return min_value - old_val

## Returns true if the cached value is non-zero, false otherwise.
func get_as_bool() -> bool:
	return cached_value != 0

## Sets the base value to 1.0 if true, or 0.0 if false.
func set_as_bool(value: bool) -> void:
	if value:
		base_value = 1.0
	else:
		base_value = 0.0

## Resets all modifiers to their default values.
func reset_modifiers() -> void:
	_enable_signal = false
	percent_modifier = 0.0
	flat_modifier = 0.0
	max_flat_modifier = 0.0
	max_percent_modifier = 0.0
	cached_value = 0.0
	cached_max = 0.0
	_enable_signal = true
	on_value_changed()

## Returns the difference between the current stat and another stat.
## [param other_stat]: The stat to compare with.
## [return]: A dictionary containing:
##           - "value_diff": The difference in the stat's value.
##           - "max_diff": The difference in the stat's max value.
func get_difference_from(other_stat: Stat) -> Dictionary:
	if not other_stat:
		push_error("Cannot calculate difference with a null stat")
		return {}

	var value_diff = other_stat.get_value() - self.get_value()
	var max_diff = other_stat.get_max() - self.get_max()

	return {
		"value_diff": value_diff,
		"max_diff": max_diff
	}

## Returns a string representation of the stat.
func string() -> String:
	return "Value: %s (Base: %s, Flat: %s, Percent: %s%%)" % [
		get_value(), base_value, flat_modifier, percent_modifier
	]

## Converts the stat to a dictionary for serialization.
func to_dict() -> Dictionary:
	return {
		"base_value": base_value,
		"flat_modifier": flat_modifier,
		"percent_modifier": percent_modifier,
		"max_flat_modifier": max_flat_modifier,
		"max_percent_modifier": max_percent_modifier,
		"min_value": min_value,
		"max_value": max_value,
		"final_value_clamped": final_value_clamped,
		"base_value_clamped": base_value_clamped,
		"flat_modifier_clamped": flat_modifier_clamped,
		"percent_modifier_clamped": percent_modifier_clamped,
		"max_flat_modifier_clamped": max_flat_modifier_clamped,
		"max_percent_modifier_clamped": max_percent_modifier_clamped,
		"flat_modifier_min": flat_modifier_min,
		"flat_modifier_max": flat_modifier_max,
		"percent_modifier_min": percent_modifier_min,
		"percent_modifier_max": percent_modifier_max,
		"max_flat_modifier_min": max_flat_modifier_min,
		"max_flat_modifier_max": max_flat_modifier_max,
		"max_percent_modifier_min": max_percent_modifier_min,
		"max_percent_modifier_max": max_percent_modifier_max,
		"stat_type": stat_type
	}

## Restores the stat from a dictionary.
func from_dict(dict: Dictionary) -> void:
	_enable_signal = false
	# Set non-clamped values first
	max_value = dict.get("max_value", max_value)
	min_value = dict.get("min_value", min_value)
	base_value = dict.get("base_value", base_value)
	flat_modifier = dict.get("flat_modifier", flat_modifier)
	percent_modifier = dict.get("percent_modifier", percent_modifier)
	max_flat_modifier = dict.get("max_flat_modifier", max_flat_modifier)
	max_percent_modifier = dict.get("max_percent_modifier", max_percent_modifier)
	# Set min/max limits
	flat_modifier_min = dict.get("flat_modifier_min", flat_modifier_min)
	flat_modifier_max = dict.get("flat_modifier_max", flat_modifier_max)
	percent_modifier_min = dict.get("percent_modifier_min", percent_modifier_min)
	percent_modifier_max = dict.get("percent_modifier_max", percent_modifier_max)
	max_flat_modifier_min = dict.get("max_flat_modifier_min", max_flat_modifier_min)
	max_flat_modifier_max = dict.get("max_flat_modifier_max", max_flat_modifier_max)
	max_percent_modifier_min = dict.get("max_percent_modifier_min", max_percent_modifier_min)
	max_percent_modifier_max = dict.get("max_percent_modifier_max", max_percent_modifier_max)
	# Set clamping flags last to trigger validation
	final_value_clamped = dict.get("final_value_clamped", final_value_clamped)
	base_value_clamped = dict.get("base_value_clamped", base_value_clamped)
	flat_modifier_clamped = dict.get("flat_modifier_clamped", flat_modifier_clamped)
	percent_modifier_clamped = dict.get("percent_modifier_clamped", percent_modifier_clamped)
	max_flat_modifier_clamped = dict.get("max_flat_modifier_clamped", max_flat_modifier_clamped)
	max_percent_modifier_clamped = dict.get("max_percent_modifier_clamped", max_percent_modifier_clamped)
	stat_type = dict.get("stat_type", stat_type)
	_enable_signal = true
	on_value_changed()
