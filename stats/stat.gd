@tool
extends Resource
## Represents a flexible and configurable stat system with support for clamping, modifiers, and serialization.[br]
##[br]
## This class provides a comprehensive stat management system, allowing for base values, flat and percent modifiers,[br]
## and maximum/minimum constraints. It supports clamping for both base and final values, ensuring stat integrity.[br]
## The class also emits signals when values change and includes utility functions for normalization, difference[br]
## calculation, and boolean representation. Additionally, it supports serialization to and from dictionaries for easy[br]
## saving and loading of stat configurations.

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
@export var enable_signal := true:
	set(value):
		enable_signal = value
		on_value_changed()

## Emitted when the stat value changes[br]
## [param new_value]: The new calculated value.[br]
## [param new_max]: The new maximum value.[br]
## [param old_value]: The previous calculated value.[br]
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

@export_group("Stat")

## Clamps the base value to be between [param min_value] and [param max_value].[br]
## If [param base_value_clamped] is true, the base value will not exceed these bounds.
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

## Clamps the final value to be between [param min_value] and [param max_value].[br]
## Does not affect the base value.
@export var final_value_clamped:bool:
	set(value):
		if final_value_clamped == value: return
		final_value_clamped = value
		on_value_changed()

## Percent modifier applied to base value.[br]
## Value of 100 means +100% (2x multiplier), not 100% total.[br]
## Formula: base_value * (1 + percent_modifier/100)
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

@export_group("Limit")
## Clamps the flat modifier to be between [param flat_modifier_min] and [param flat_modifier_max].[br]
## If [param flat_modifier_clamped] is true, the flat modifier will not exceed these bounds.
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

## Clamps the percent modifier to be between [param percent_modifier_min] and [param percent_modifier_max].[br]
## If [param percent_modifier_clamped] is true, the percent modifier will not exceed these bounds.
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

## Clamps the max percent modifier to be between [param max_percent_modifier_min] and [param max_percent_modifier_max].[br]
## If [param max_percent_modifier_clamped] is true, the max percent modifier will not exceed these bounds.
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

## Clamps the max flat modifier to be between [param max_flat_modifier_min] and [param max_flat_modifier_max].[br]
## If [param max_flat_modifier_clamped] is true, the max flat modifier will not exceed these bounds.
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

## Constructor for initializing the stat.[br]
## [param _base_value]: Initial base value (default: 0.0).[br]
## [param _base_value_clamped]: Whether the base value is clamped (default: true).[br]
## [param _min_value]: Minimum value (default: 0.0).[br]
## [param _max_value]: Maximum value (default: 100.0).[br]
## [param _final_value_clamped]: Whether the final value is clamped (default: false).[br]
## [param _flat_modifier]: Initial flat modifier (default: 0.0).[br]
## [param _percent_modifier]: Initial percent modifier (default: 0.0).[br]
## [param _max_percent_modifier]: Initial max percent modifier (default: 0.0).[br]
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

## Returns the calculated value of the stat.[br]
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

## Sets the base value directly without any modifiers or calculations.
func set_direct_value(amount: float) -> float:
	if frozen: return 0.0
	var old_val = base_value
	base_value = get_typed_value(amount)
	return base_value - old_val

## Sets the base value directly without any modifiers or calculations.
func set_base_value(new_base: float) -> float:
	return set_direct_value(new_base)

## Sets the maximum value directly without any modifiers or calculations.
func set_max_value(new_max: float) -> float:
	if frozen: return 0.0	
	var old_max = max_value
	max_value = get_typed_value(new_max)
	return max_value - old_max

## Sets the minimum value directly without any modifiers or calculations.
func set_min_value(new_min: float) -> float:
	if frozen: return 0.0	
	var old_min = min_value
	min_value = get_typed_value(new_min)
	return min_value - old_min

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

## Utility: Retrieve a Stat from an object by name.
## Searches via get_stat() method if available, else tries direct property access.
## Returns null if not found or not a Stat.
static func get_stat(parent: Object, name: String, warn: bool = false) -> Stat:
	if parent == null:
		if warn:
			push_warning("Stat.get_stat(): parent is null")
		return null

	var stat: Stat = null

	# If parent has custom getter (common in entities)
	if parent.has_method("get_stat"):
		stat = parent.get_stat(name) as Stat

	# If not found yet, try normalized property
	if stat == null:
		var normalized := name.to_snake_case()
		stat = parent.get(normalized) as Stat

	# Warn only if still missing
	if stat == null and warn:
		push_warning("Stat.get_stat(): Could not find stat '%s' in %s" % [name, parent])

	return stat

## Returns the difference between the current stat and another stat.[br]
## [param other_stat]: The stat to compare with.[br]
## [return]: A dictionary containing:[br]
##           - "old_value": The current value of the stat.[br]
##           - "old_max": The current maximum value of the stat.[br]
##           - "value_diff": The difference in the stat's value.[br]
##           - "max_diff": The difference in the stat's max value.
func get_difference_from(other_stat: Stat) -> Dictionary:
	if not other_stat:
		push_error("Cannot calculate difference with a null stat")
		return {}

	var value_diff = other_stat.get_value() - self.get_value()
	var max_diff = other_stat.get_max() - self.get_max()

	return {
		"old_value": get_value(),
		"old_max": get_max(),
		"value_diff": value_diff,
		"max_diff": max_diff
	}

## Bind stat to a callable (most flexible, fastest)
func bind_to(callable: Callable) -> void:
	value_changed.connect(func(nv, _nm, _ov, _om): callable.call(nv))
	callable.call(get_value())

## Binds the stat to a property on a target object.
func bind_to_property(target: Object, property: StringName) -> void:
	value_changed.connect(func(nv, _nm, _ov, _om):
		target.set(property, nv)
	)
	target.set(property, get_value())

## Binds the stat to a property on a target object.
static func bind_property(target: Object, property: StringName, stat: Stat) -> void:
	stat.bind_to_property(target, property)

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

#region Factory Methods
## Creates a stat with just a base value, no clamping.[br]
## Useful for stats that can grow unbounded (damage, speed bonuses, etc.)
static func create_value(base: float) -> Stat:
	var s = Stat.new()
	s.base_value = base
	s.base_value_clamped = false
	s.final_value_clamped = false
	return s

## Creates a clamped stat with min/max bounds.[br]
## Useful for resources (health, mana, shield) or percentage stats (0-1 range).
static func create_clamped(base: float, minimum: float, maximum: float) -> Stat:
	var s = Stat.new()
	s.base_value = base
	s.min_value = minimum
	s.max_value = maximum
	s.base_value_clamped = true
	s.final_value_clamped = true
	return s

## Creates a clamped stat where base starts at max.[br]
## Common pattern for health/shield initialization.
static func create_full(maximum: float, minimum: float = 0.0) -> Stat:
	var s = Stat.new()
	s.base_value = maximum
	s.min_value = minimum
	s.max_value = maximum
	s.base_value_clamped = true
	s.final_value_clamped = true
	return s

## Creates a percentage stat (0.0 to 1.0 range, clamped).[br]
## Useful for crit chance, damage resistance, etc.
static func create_percentage(base: float = 0.0, maximum: float = 1.0, minimum: float = 0.0) -> Stat:
	return create_clamped(base, minimum, maximum)
#endregion
