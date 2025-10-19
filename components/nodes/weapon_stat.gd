class_name WeaponStat
extends RefCounted

## Helper class for calculating weapon stats using the formula:
## final = local_base + (global_scaling * global_value)

var local_stat: Stat
var global_stat: Stat
var global_scaling: float

signal value_changed(old_value: float, new_value: float)

func _init(_local_stat: Stat, _global_stat: Stat = null, _global_scaling: float = 1.0) -> void:
	local_stat = _local_stat
	global_stat = _global_stat
	global_scaling = _global_scaling
	
	# Connect to stat changes
	if local_stat:
		local_stat.value_changed.connect(_on_stat_changed)
	if global_stat:
		global_stat.value_changed.connect(_on_stat_changed)

func get_final_value() -> float:
	var local_value = local_stat.get_value() if local_stat else 0.0
	var global_value = global_stat.get_value() if global_stat else 0.0
	return local_value + (global_scaling * global_value)

func set_global_stat(_global_stat: Stat) -> void:
	if global_stat and global_stat.value_changed.is_connected(_on_stat_changed):
		global_stat.value_changed.disconnect(_on_stat_changed)
	
	global_stat = _global_stat
	
	if global_stat:
		global_stat.value_changed.connect(_on_stat_changed)

func set_global_scaling(_scaling: float) -> void:
	global_scaling = _scaling

func _on_stat_changed(old_val: float, new_val: float) -> void:
	value_changed.emit(old_val, new_val)

func get_local_stat() -> Stat:
	return local_stat

func get_global_stat() -> Stat:
	return global_stat
