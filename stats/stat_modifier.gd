@tool
extends Resource

## Class for managing stat modifications.
class_name StatModifier

signal on_applied
signal on_removed

## Enum defining types of stat modifications.
## Keep this as enum for inspector compatibility
enum StatModifierType {
	FLAT, ## Flat modifier
	PERCENT, ## Percent modifier
	VALUE, ## Value modifier
	MAX_VALUE, ## Max value modifier
	MAX_FLAT, ## Max flat modifier
	MAX_PERCENT, ## Max percent modifier
	MIN_VALUE, ## Min value modifier
	PERCENT_NORMALIZED, ## Percent normalized modifier value can be between 0 and 1
	MAX_PERCENT_NORMALIZED, ## Max percent normalized modifier value can be between 0 and 1
	SET_BASE, ## Set base value of a stat use only in special cases as directly settig value cant be tracked.
	SET_MAX_VALUE, ## Set max value of a stat use only in special cases as directly settig value cant be tracked.
	SET_MIN_VALUE ## Set min value of a stat use only in special cases as directly settig value cant be tracked.
}

## Enum defining strategies for merging modifiers
enum MergeStrategy {
	ADD,        # Current behavior: _value += mod._value
	OVERRIDE,   # Take new value: _value = mod._value
	MAX,        # Take larger: _value = max(_value, mod._value)
	MIN         # Take smaller: _value = min(_value, mod._value)
}

## Name of the stat this modifier affects.
@export var _stat_name: String

## Type of the modification (e.g., FLAT, PERCENT, etc.).
@export var _type: StatModifierType

## The value of the modification to apply.
@export var _value: float

## Whether this modifier should only be applied once.
@export var _apply_only_once := true

## The strategy to use when merging modifiers.
@export var merge_strategy := MergeStrategy.ADD

## The stat instance this modifier is linked to.
var _stat: Stat

## Is this modifier currently applied
@export_storage var _is_applied := false
@export_storage var _applied_value := 0.0

## Initializes the modifier with the provided stat name, type, and value.
func _init(stat_name: String = "", type: StatModifierType = StatModifierType.FLAT, value: float = 0.0) -> void:
	self._stat_name = stat_name
	self._type = type
	self._value = value

## Initializes the stat reference by fetching it from the provided parent.
## [param parent]: The node to fetch the stat from.
func init_stat(parent: Object) -> bool:
	if parent == null:
		push_error("Cannot initialize stat with null parent")
		return false
		
	if _stat != null: 
		uninit_stat()
	
	if parent.has_method("get_stat"):
		_stat = parent.get_stat(_stat_name)
		
	if _stat == null:
		var normalized_name = _stat_name.to_snake_case()
		_stat = parent.get(normalized_name) as Stat
	
	if _stat == null:
		push_warning("Could not find stat named '%s' in parent" % _stat_name)
		return false

	return true

## Clears the stat reference to uninitialize the modifier.
func uninit_stat(remove_all:bool = true) -> void:
	if remove_all: remove()
	_is_applied = false
	_applied_value = 0.0
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
		
	match merge_strategy:
		MergeStrategy.ADD:
			set_value(_value + mod._value)
		MergeStrategy.OVERRIDE:
			set_value(mod._value)
		MergeStrategy.MAX:
			set_value(max(_value, mod._value))
		MergeStrategy.MIN:
			set_value(min(_value, mod._value))
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
	if _is_applied:
		remove()
		self._value = value
		apply()
	else:
		self._value = value

## Sets the type of the modifier.
## [param type]: The type to set.
func set_type(type: StatModifierType = StatModifierType.FLAT) -> void:
	if _is_applied:
		remove()
		self._type = type
		apply()
	else:
		self._type = type

## Applies a specified type of stat modifier to the given stat.
## [param type]: The type of stat modifier to apply (e.g., FLAT, PERCENT).
## [param stat]: The stat object to which the modifier will be applied.
## [param value]: The value associated with the modifier.
## [return]: The actual change in the stat as a result of applying the modifier.
func _apply_stat_modifier(type, stat, value) -> float:
	var actual_change = 0.0
	match type:
		StatModifierType.FLAT:
			actual_change = stat.add_flat(value)
		StatModifierType.PERCENT:
			actual_change = stat.add_percent(value)
		StatModifierType.MAX_FLAT:
			actual_change = stat.add_max_flat(value)
		StatModifierType.MAX_PERCENT:
			actual_change = stat.add_max_percent(value)
		StatModifierType.VALUE:
			actual_change = stat.add_value(value)
		StatModifierType.MAX_VALUE:
			actual_change = stat.add_max_value(value)
		StatModifierType.MIN_VALUE:
			actual_change = stat.add_min_value(value)
		StatModifierType.PERCENT_NORMALIZED:
			actual_change = stat.add_percent(value * 100.0)
		StatModifierType.MAX_PERCENT_NORMALIZED:
			actual_change = stat.add_max_percent(value * 100.0)
		StatModifierType.SET_BASE:
			actual_change = stat.set_base(value)
		StatModifierType.SET_MAX_VALUE:
			actual_change = stat.set_max_value(value)
		StatModifierType.SET_MIN_VALUE:
			actual_change = stat.set_min_value(value)
	return actual_change

## Returns a duplicate of the stat with the modifier applied.
func get_temp_applied_stat() -> Stat:
	var temp_stat = _stat.duplicate(true)
	_apply_stat_modifier(_type, temp_stat, _value)
	return temp_stat

## Simulates the effect of applying this modifier without changing the actual stat.
## [return]: A dictionary containing:
##           - "old_value": The predicted change in the stat's min value.
##           - "old_max": The predicted change in the stat's max value.
##           - "value_diff": The predicted change in the stat's value.
##           - "max_diff": The predicted change in the stat's max value.
func simulate_effect() -> Dictionary:
	if not is_valid():
		push_warning("Cannot simulate effect with an invalid stat reference")
		return {}

	var temp_stat = get_temp_applied_stat()
	return _stat.get_difference_from(temp_stat)

## Applies the modifier to the stat and returns the actual amount applied
func apply(apply_value:float = 0.0) -> float:
	if not is_valid(): return 0.0
	if _is_applied and _apply_only_once:
		return 0.0
	if apply_value == 0.0:
		apply_value = _value
	
	var actual_change = _apply_stat_modifier(_type, _stat, apply_value)
	
	if actual_change == 0.0: return 0.0
	_is_applied = true
	_applied_value += actual_change  # Track total applied effect
	on_applied.emit()
	return actual_change

## Removes the modifier from the stat and returns the actual amount changed [br]
## [param remove_all]: Whether to remove the entire amount applied by this modifier. [br]
## [return]: The actual amount removed by this modifier.
func remove(remove_all: bool = true) -> float:
	if not is_valid():
		return 0.0
	if not _is_applied:
		return 0.0

	# Early exit since SET_* modifiers cannot be undone numerically
	if _type == StatModifierType.SET_BASE \
	or _type == StatModifierType.SET_MIN_VALUE \
	or _type == StatModifierType.SET_MAX_VALUE:
		_applied_value = 0.0
		_is_applied = false
		on_removed.emit()
		return 0.0

	# Determine how much to remove
	var removal_amount := _value
	if remove_all or _apply_only_once:
		removal_amount = _applied_value
	elif _value > 0.0 and _applied_value - _value < 0.0:
		removal_amount = _applied_value
	elif _value < 0.0 and _applied_value - _value > 0.0:
		removal_amount = _applied_value

	# Apply the inverse change to the stat (can be clamped)
	var actual_change := _apply_stat_modifier(_type, _stat, -removal_amount)

	# Always update logical applied value even if clamped prevented full change
	_applied_value = max(0.0, _applied_value - abs(removal_amount))

	# Clean up state if fully removed
	if _applied_value <= 0.000001:
		_is_applied = false

	on_removed.emit()
	return actual_change

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

## Interpolates the value of this modifier using the provided other modifier and lerp t value.
## [param other]: The other modifier to interpolate with.[br]
## [param t]: The lerp t value.
func interpolate(other: StatModifier, t: float) -> void:
	set_value(lerp(_value, other._value, t))

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
		"apply_only_once": _apply_only_once,
		"applied_value" : _applied_value,
		"merge_strategy": merge_strategy
	}

## Loads this modifier from a dictionary.
func from_dict(dict: Dictionary) -> void:
	_stat_name = dict.get("stat_name", _stat_name)
	_type = dict.get("type", _type)
	_value = dict.get("value", _value)
	_is_applied = dict.get("is_applied", _is_applied)
	_apply_only_once = dict.get("apply_only_once", _apply_only_once)
	_applied_value = dict.get("applied_value", _applied_value)
	merge_strategy = dict.get("merge_strategy", merge_strategy)
