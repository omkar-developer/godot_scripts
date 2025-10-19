class_name ScaledStat
extends RefCounted

## A stat that automatically calculates: base + (parent * scaling)
## Auto-updates when any source stat changes and can be bound to properties

var base_stat: Stat
var parent_stat: Stat
var scaling_stat: Stat
var _cached_value: float = 0.0

signal value_changed(new_value: float)

func _init(_base: Stat, _parent: Stat, _scaling: Stat) -> void:
	base_stat = _base
	parent_stat = _parent
	scaling_stat = _scaling
	
	# Connect to all stat changes
	if base_stat:
		base_stat.value_changed.connect(_on_stat_changed)
	if parent_stat:
		parent_stat.value_changed.connect(_on_stat_changed)
	if scaling_stat:
		scaling_stat.value_changed.connect(_on_stat_changed)
	
	# Calculate initial value
	_recalculate()

func _on_stat_changed(_new_value: float, _new_max: float = 0.0, _old_value: float = 0.0, _old_max: float = 0.0) -> void:
	_recalculate()

func _recalculate() -> void:
	var new_value = _calculate()
	if new_value != _cached_value:
		_cached_value = new_value
		value_changed.emit(new_value)

func _calculate() -> float:
	if not base_stat:
		return 0.0
	
	var base = base_stat.get_cached_value()
	if parent_stat and scaling_stat:
		base += parent_stat.get_cached_value() * scaling_stat.get_cached_value()
	return base

func get_value() -> float:
	return _cached_value

## Bind scaled stat to a property on target object
## Auto-updates property when any source stat changes
func bind_to_property(target: Object, property: StringName) -> void:
	value_changed.connect(func(nv: float):
		target.set(property, nv)
	)
	# Set initial value
	target.set(property, get_value())

## Bind to a callable (most flexible)
func bind_to(callable: Callable) -> void:
	value_changed.connect(callable)
	callable.call(get_value())
