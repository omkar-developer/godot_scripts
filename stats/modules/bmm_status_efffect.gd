class_name BMMStatusEffect
extends BMModule

signal status_started(effect_name: String, modifier: StatModifierSet)
signal status_ended(effect_name: String, modifier: StatModifierSet)
signal status_refreshed(effect_name: String, modifier: StatModifierSet)

@export var filter_list: Array[String] = []
@export var filter_exclude: bool = false ## true: exclude modifiers in the list, false: include modifiers in the list
@export var track_by_group: bool = false ## Use group names instead of modifier names for filtering

var total_count: int = 0
var active_effects: Dictionary = {}  # effect_name -> count

func _should_track(modifier: StatModifierSet) -> bool:
	# Empty filter = track all
	if filter_list.is_empty():
		return not filter_exclude
	
	var check_name = modifier._group if track_by_group else modifier.get_modifier_name()
	var in_list = filter_list.has(check_name)
	
	# Exclude mode: track if NOT in list
	# Include mode: track if IN list
	return in_list != filter_exclude

func on_after_apply(modifier: StatModifierSet) -> void:
	if not _should_track(modifier):
		return
	
	var mod_name = modifier.get_modifier_name()
	var instances = manager.get_modifier_instances(mod_name)
	
	# Update tracking
	if not active_effects.has(mod_name):
		active_effects[mod_name] = 0
	active_effects[mod_name] += 1
	total_count += 1
	
	# Emit appropriate signal
	if instances.size() == 1:
		status_started.emit(mod_name, modifier)
	else:
		status_refreshed.emit(mod_name, modifier)

func on_after_remove(modifier: StatModifierSet) -> void:
	var mod_name = modifier.get_modifier_name()
	
	if not active_effects.has(mod_name):
		return
	
	# Update tracking
	active_effects[mod_name] -= 1
	total_count = max(0, total_count - 1)
	
	# Clean up if no more instances
	if not manager.has_modifier(mod_name):
		active_effects.erase(mod_name)
		status_ended.emit(mod_name, modifier)

## Get count of specific effect
func get_effect_count(effect_name: String) -> int:
	return active_effects.get(effect_name, 0)

## Get all tracked effect names
func get_active_effects() -> Array[String]:
	var effects: Array[String] = []
	effects.assign(active_effects.keys())
	return effects

## Check if specific effect is active
func has_effect(effect_name: String) -> bool:
	return active_effects.has(effect_name) and active_effects[effect_name] > 0

## Clear tracking (useful on reset)
func clear_tracking() -> void:
	active_effects.clear()
	total_count = 0

## Serialization
func to_dict() -> Dictionary:
	return {
		"filter_list": filter_list,
		"filter_exclude": filter_exclude,
		"track_by_group": track_by_group,
		"total_count": total_count,
		"active_effects": active_effects.duplicate()
	}

func from_dict(data: Dictionary) -> void:
	filter_list = data.get("filter_list", [])
	filter_exclude = data.get("filter_exclude", false)
	track_by_group = data.get("track_by_group", false)
	total_count = data.get("total_count", 0)
	active_effects = data.get("active_effects", {}).duplicate()