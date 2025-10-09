@tool
extends Resource

## A class that represents a set of stat _modifiers and provides methods to manage and apply them.
class_name StatModifierSet

signal on_effect_apply # Signal emitted when an effect is applied to a stat.
signal on_effect_remove # Signal emitted when an effect is removed from a stat. 

## Array of _modifiers in this set.
@export var _modifiers: Array[StatModifier] = []

## The name of this modifier set.
@export var _modifier_name: String = ""

## The group to which this modifier set belongs.
@export var _group := ""

## Whether to merge modifiers with the same name.
@export var merge_enabled := true

## Whether to process this modifier set every frame.
@export var process := false

## apply as soon as initialized or added to the list
@export var _apply := true
## remove effect when uninit
@export var _remove_all := true
## remove as soon as applied (effect will not be removed)
@export var consumable := false

enum StackMode {
	MERGE_VALUES,      # Combine values (default)
	COUNT_STACKS,      # Track application count
	INDEPENDENT,       # Separate instances
}

@export var stack_mode := StackMode.MERGE_VALUES
@export var max_stacks := -1
@export var stack_source_id := ""
var stack_count := 1

@export_group("Signal")
@export var apply_on_signal := false
@export var remove_on_signal := false
@export var pause_on_apply_signal := false
@export var resume_on_apply_signal := false
@export var pause_on_remove_signal := false
@export var resume_on_remove_signal := false
@export var apply_signal := ""
@export var remove_signal := ""

@export_group("Condition")
## The condition associated with this modifier set.
@export var condition: Condition
## Whether to apply effects when the condition changes.
@export var apply_on_condition_change := true
## Whether to remove effects when the condition changes.
@export var remove_on_condition_change := true
## apply effect when condition is true when initializing 
@export var _condition_apply_on_start := true
## pause process when condition is false and vice versa
@export var _condition_pause_process := false

## Stack decay settings
@export var enable_stack_decay: bool = false
@export var stack_decay_interval: float = 1.0  # Seconds between decay ticks
@export var stack_decay_amount: int = 1  # Stacks to remove per tick (-1 = remove all)
@export var stack_decay_min: int = 0  # Minimum stacks (usually 0, but can be higher)
@export var refresh_decay_on_stack: bool = false  # Reset timer when new stack added
@export var remove_on_zero_stacks: bool = true  # Delete modifier when stacks reach min

@export_storage var _stack_decay_timer: float = 0.0

var _marked_for_deletion := false

## The _parent object associated with this modifier set.
var _parent: Object

## Return the modifer name
func get_modifier_name() -> String:
	return _modifier_name

## Initialize a new modifier set.
func _init(modifier_name := "", _process_every_frame := false, group := "") -> void:
	_modifier_name = modifier_name
	_group = group
	process = _process_every_frame

## Called when the apply signal is emitted
func _on_apply_signal() -> void:
	if apply_on_signal: _apply_effect()
	if pause_on_apply_signal: process = false
	if resume_on_apply_signal: process = true

## Called when the remove signal is emitted
func _on_remove_signal() -> void:
	if remove_on_signal: _remove_effect()
	if pause_on_remove_signal: process = false
	if resume_on_remove_signal: process = true

## Connects the apply and remove signals to the parent object
func _connect_signals() -> void:
	if apply_signal.is_empty() and remove_signal.is_empty():
		return
	if _parent == null:
		return

	var apply_sig = null
	var remove_sig = null

	if _parent.has_method("get_signal"):
		apply_sig = _parent.get_signal(apply_signal)
		remove_sig = _parent.get_signal(remove_signal)

	if apply_sig != null:
		if not apply_sig.is_connected(_on_apply_signal):
			apply_sig.connect(_on_apply_signal)
	elif not apply_signal.is_empty() and _parent.has_signal(apply_signal):
		if not _parent.is_connected(apply_signal, _on_apply_signal):
			_parent.connect(apply_signal, _on_apply_signal)
	else:
		push_error("Failed to connect apply signal: " + str(apply_signal))

	if remove_sig != null:
		if not remove_sig.is_connected(_on_remove_signal):
			remove_sig.connect(_on_remove_signal)
	elif not remove_signal.is_empty() and _parent.has_signal(remove_signal):
		if not _parent.is_connected(remove_signal, _on_remove_signal):
			_parent.connect(remove_signal, _on_remove_signal)
	else:
		push_error("Failed to connect remove signal: " + str(remove_signal))


## Disconnects the apply and remove signals from the parent object
func _disconnect_signals() -> void:
	if apply_signal.is_empty() and remove_signal.is_empty():
		return
	if _parent == null:
		return

	var apply_sig = null
	var remove_sig = null

	if _parent.has_method("get_signal"):
		apply_sig = _parent.get_signal(apply_signal)
		remove_sig = _parent.get_signal(remove_signal)

	if apply_sig != null:
		if apply_sig.is_connected(_on_apply_signal):
			apply_sig.disconnect(_on_apply_signal)
	elif _parent.has_signal(apply_signal) and _parent.is_connected(apply_signal, _on_apply_signal):
		_parent.disconnect(apply_signal, _on_apply_signal)

	if remove_sig != null:
		if remove_sig.is_connected(_on_remove_signal):
			remove_sig.disconnect(_on_remove_signal)
	elif _parent.has_signal(remove_signal) and _parent.is_connected(remove_signal, _on_remove_signal):
		_parent.disconnect(remove_signal, _on_remove_signal)

## Called when the condition state changes
func _on_condition_changed(result: bool) -> void:
	if result:
		if apply_on_condition_change: _apply_effect()
		if _condition_pause_process: process = true
	else:
		if remove_on_condition_change: _remove_effect()
		if _condition_pause_process: process = false

## Connects condition signals and handles initial state
func _connect_condition() -> void:
	if condition != null and not condition.condition_changed.is_connected(_on_condition_changed):
		condition.condition_changed.connect(_on_condition_changed)

## Disconnects condition signals
func _disconnect_condition() -> void:
	if condition != null and condition.condition_changed.is_connected(_on_condition_changed):
		condition.condition_changed.disconnect(_on_condition_changed)

## Merges a parallel StatModifierSet into this one.[br]
## [param modifer_set]: The StatModifierSet to merge.
func _merge_parallel(modifer_set: StatModifierSet) -> void:
	if modifiers_count() != modifer_set.modifiers_count(): return
	for i in range(modifer_set.modifiers_count() - 1, -1, -1):
		if modifer_set._modifiers[i].is_equal(_modifiers[i]):
			_modifiers[i].merge(modifer_set._modifiers[i])

## Merges a StatModifierSet into this one.[br]
## [param mod]: The StatModifierSet to merge.
func merge_mod(mod: StatModifierSet) -> bool:
	if not merge_enabled: return false
	
	match stack_mode:
		StackMode.MERGE_VALUES:
			_merge_parallel(mod)
			return true
		
		StackMode.COUNT_STACKS:
			if max_stacks > 0 and stack_count >= max_stacks:
				return false
			stack_count += 1
			
			# Refresh decay timer if enabled
			if refresh_decay_on_stack and enable_stack_decay:
				_stack_decay_timer = 0.0
			
			_apply_effect()
			return true
		
		StackMode.INDEPENDENT:
			push_warning("merge_mod called on INDEPENDENT mode - should not happen")
			return false
	
	return false

## Sets the value of a modifier at a given index.[br]
## [param mod_idx]: The index of the modifier to set the value of.[br]
## [param value]: The value to set.
## [return]: True if the value was set, False otherwise.
func set_mod_value(mod_idx: int, value: float) -> bool:
	if _modifiers.size() > mod_idx:
		_modifiers[mod_idx].set_value(value)
		return true
	else:
		push_error("Invalid modifier index: " + str(mod_idx))
		return false

## Finds a modifier in this set that matches the given modifier.[br]
## [param mod]: The modifier to find.[br]
## [return]: The modifier that matches the given modifier, or null if no such modifier is found.
func find_mod(mod: StatModifier) -> StatModifier:
	for mod2 in _modifiers:
		if mod.is_equal(mod2):
			return mod2
	return null

## Finds a modifier that targets a given stat and has a given type.[br]
## [param stat_name]: The name of the stat to target.[br]
## [param type]: The type of the modifier to find.[br]
## [return]: The modifier that targets the given stat and has the given type, or null if no such modifier is found.
func find_mod_by_name_and_type(stat_name: String, type: StatModifier.StatModifierType) -> StatModifier:
	for mod in _modifiers:
		if mod.get_stat_name() == stat_name and mod.get_type() == type:
			return mod
	return null

## Finds a modifier that targets a given stat.[br]
## [param stat_name]: The name of the stat to target.[br]
## [return]: The modifier that targets the given stat, or null if no such modifier is found.
func find_mod_for_stat(stat_name: String) -> StatModifier:
	for mod in _modifiers:
		if mod.get_stat_name() == stat_name:
			return mod
	return null

## Applies all _modifiers in this set to the _parent.
func _apply_effect() -> void:
	for mod in _modifiers:
		mod.apply()
	on_effect_apply.emit()

## Removes all _modifiers in this set from the _parent.
func _remove_effect() -> void:
	for mod in _modifiers:
		mod.remove()
	on_effect_remove.emit()

## Removes a given number of stacks from all _modifiers in this set.
func _remove_stack_effect(stack_count_to_remove: int = 1) -> void:
	if stack_count_to_remove <= 0:
		return

	for mod in _modifiers:
		if mod.is_valid():
			for i in stack_count_to_remove:
				mod.remove(false)  # remove one stack worth of value each time

	on_effect_remove.emit()

## Initializes all _modifiers in this set with the given _parent.[br]
## [param _parent]: The _parent to initialize the _modifiers with.
## [param apply_effect]: Whether to apply the effects of the _modifiers.
func init_modifiers(parent: Object, apply_effect := true) -> void:
	if _parent != null: 
		push_error("Attempted to set new parent while already initialized without uninitializing first.")
		return
	if parent == null: return
	_parent = parent
	for mod in _modifiers:
		mod.init_stat(parent)
	# Initialize condition first
	if condition != null:
		condition.init_stat(parent)
		_connect_condition()
		if _condition_apply_on_start and apply_effect:
			_apply_effect()
			if _condition_pause_process: process = condition.get_condition()
	
	# initialize signals
	_connect_signals()

	# Apply effects
	if ((_apply and apply_effect) or consumable) and condition == null:
		_apply_effect()
	
	if consumable:
		delete()

## Uninitializes all _modifiers in this set.
func uninit_modifiers() -> void:
	_disconnect_signals()
	if condition != null:
		_disconnect_condition()
		condition.uninit_stat()
	_parent = null
	for mod in _modifiers:
		mod.uninit_stat(_remove_all)

## Adds a modifier to this set.[br]
## [param mod]: The modifier to add.
func add_modifier(mod: StatModifier) -> StatModifier:
	if _marked_for_deletion or mod == null: return null
	var mod2 = mod.duplicate(true)
	_modifiers.append(mod2)
	mod2.init_stat(_parent)
	# Only apply if conditions are met
	if _apply and condition == null:
		mod2.apply()
	if condition != null and _condition_apply_on_start:
		mod2.apply()
	return mod2

## Removes a modifier from this set.[br]
## [param mod]: The modifier to remove.
func remove_modifier(mod: StatModifier) -> void:
	var mod2 = find_mod(mod)
	if mod2 == null: return
	mod2.uninit_stat(_remove_all)
	_modifiers.erase(mod2)

## Returns a reference to the modifier at the specified index. If the index is out of range, returns null.
func modifier_at(index: int) -> StatModifier:
	if index < 0 or index >= len(_modifiers): return null   
	return _modifiers[index]

## Returns the number of _modifiers in this set.
func modifiers_count() -> int:    
	return len(_modifiers)

## Clears all _modifiers in this set.
func clear_modifiers() -> void:    
	for mod in _modifiers:
		mod.uninit_stat(_remove_all)
	_modifiers.clear()

## Clears all _modifiers in this set and uninitializes the condition and disconnects signals.
func clear_all() -> void:
	clear_modifiers()
	_disconnect_signals()
	if condition != null:
		condition.uninit_stat()
		_disconnect_condition()

## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if condition != null:
		condition._process(delta)

	if enable_stack_decay and stack_mode == StackMode.COUNT_STACKS:
		_stack_decay_timer += delta

		if _stack_decay_timer >= stack_decay_interval:
			# Calculate how many decay ticks should happen
			var ticks_to_apply = int(_stack_decay_timer / stack_decay_interval)
			_stack_decay_timer -= ticks_to_apply * stack_decay_interval

			# Reduce stacks accordingly
			var total_decay = stack_decay_amount * ticks_to_apply
			if stack_decay_amount == -1:
				stack_count = stack_decay_min
			else:
				stack_count = max(stack_decay_min, stack_count - total_decay)

			# Remove effect entirely if below threshold
			if stack_count <= stack_decay_min:
				if remove_on_zero_stacks:
					delete()
					return
				# else keep the remaining stacks and leftover timer

			else:
				# Apply reduced effect for each tick (if needed)
				for _i in range(ticks_to_apply):
					_remove_stack_effect()
	
## Deletes this modifier set.
func delete() -> void:
	process = false
	_disconnect_signals()
	if condition != null:
		_disconnect_condition()
		condition.uninit_stat()
	clear_modifiers()
	_marked_for_deletion = true

## Returns true if this modifier set is marked for deletion, false otherwise.
func is_marked_for_deletion() -> bool:
	return _marked_for_deletion

## Make copy of this modifier set
func copy() -> StatModifierSet:
	var mod_set = StatModifierSet.new(_modifier_name, process, _group)
	for mod in _modifiers:
		mod_set._modifiers.append(mod.copy())
	mod_set.condition = condition.duplicate(true) if condition else null    
	mod_set.process = process
	mod_set._marked_for_deletion = _marked_for_deletion
	mod_set._group = _group
	mod_set._remove_all = _remove_all
	mod_set.merge_enabled = merge_enabled
	mod_set._condition_apply_on_start = _condition_apply_on_start
	mod_set._condition_pause_process = _condition_pause_process
	mod_set.apply_on_condition_change = apply_on_condition_change
	mod_set.remove_on_condition_change = remove_on_condition_change
	mod_set.consumable = consumable
	mod_set.apply_on_signal = apply_on_signal
	mod_set.remove_on_signal = remove_on_signal
	mod_set.apply_signal = apply_signal
	mod_set.remove_signal = remove_signal
	mod_set._apply = _apply
	mod_set.pause_on_apply_signal = pause_on_apply_signal
	mod_set.pause_on_remove_signal = pause_on_remove_signal
	mod_set.resume_on_apply_signal = resume_on_apply_signal
	mod_set.resume_on_remove_signal = resume_on_remove_signal
	mod_set.stack_mode = stack_mode
	mod_set.max_stacks = max_stacks
	mod_set.stack_count = stack_count
	mod_set.stack_source_id = stack_source_id
	mod_set.enable_stack_decay = enable_stack_decay
	mod_set.stack_decay_interval = stack_decay_interval
	mod_set.stack_decay_amount = stack_decay_amount
	mod_set.stack_decay_min = stack_decay_min
	mod_set.refresh_decay_on_stack = refresh_decay_on_stack
	mod_set.remove_on_zero_stacks = remove_on_zero_stacks
	mod_set._stack_decay_timer = _stack_decay_timer
	
	return mod_set

## Interpolates this modifier set with another modifier set.[br]
## [param other]: The other modifier set to interpolate with.[br]
## [param t]: The interpolation factor.[br]
## Returns the interpolated modifier set.
func interpolate_with(other: StatModifierSet, t: float):
	if other == null: return
	for i in range(min(len(_modifiers), len(other._modifiers))):
		if _modifiers[i].is_equal(other._modifiers[i]):
			_modifiers[i].interpolate(other._modifiers[i], t)

## Returns a dictionary representation of this modifier set.
func to_dict() -> Dictionary:
	return {
		"modifiers": _modifiers.map(func(m: StatModifier):
			return {"class_name": m.get_script().get_global_name(),"data": m.to_dict()}),
		"modifier_name": _modifier_name,
		"group": _group,
		"process": process,
		"condition": condition.to_dict() if condition else {},
		"condition_class": condition.get_script().get_global_name() if condition else "",
		"marked_for_deletion": _marked_for_deletion,
		"remove_all": _remove_all,
		"merge_enabled": merge_enabled,
		"condition_apply_on_start": _condition_apply_on_start,
		"condition_pause_process": _condition_pause_process,
		"apply_on_condition_change": apply_on_condition_change,
		"remove_on_condition_change": remove_on_condition_change,
		"apply": _apply,
		"consumable": consumable,
		"apply_on_signal": apply_on_signal,
		"remove_on_signal": remove_on_signal,
		"apply_signal": apply_signal,
		"remove_signal": remove_signal,
		"pause_on_apply_signal": pause_on_apply_signal,
		"pause_on_remove_signal": pause_on_remove_signal,
		"resume_on_apply_signal": resume_on_apply_signal,
		"resume_on_remove_signal": resume_on_remove_signal,
		"stack_mode": stack_mode,
		"max_stacks": max_stacks,
		"stack_source_id": stack_source_id,
		"stack_count": stack_count,
		"enable_stack_decay": enable_stack_decay,
		"stack_decay_interval": stack_decay_interval,
		"stack_decay_amount": stack_decay_amount,
		"stack_decay_min": stack_decay_min,
		"refresh_decay_on_stack": refresh_decay_on_stack,
		"remove_on_zero_stacks": remove_on_zero_stacks,
		"stack_decay_timer": _stack_decay_timer
	}

## Loads this modifier set from a dictionary.
func from_dict(data: Dictionary, parent: Object = null) -> void:
	if data == null: return

	if parent != null:		
		_parent = parent
	
	clear_all()
	
	_modifiers.assign(data.get("modifiers", []).map(
		func(m_data: Dictionary): 
			var m = _instantiate_class(m_data.get("class_name", ""))
			m.from_dict(m_data["data"])
			m.init_stat(_parent)
			return m
	))
	
	_modifier_name = data.get("modifier_name", "")
	_group = data.get("group", "")
	process = data.get("process", false)
	_marked_for_deletion = data.get("marked_for_deletion", false)
	_remove_all = data.get("remove_all", true)
	merge_enabled = data.get("merge_enabled", true)
	_condition_apply_on_start = data.get("condition_apply_on_start", true)
	_condition_pause_process = data.get("condition_pause_process", false)
	apply_on_condition_change = data.get("apply_on_condition_change", true)
	remove_on_condition_change = data.get("remove_on_condition_change", true)
	_apply = data.get("apply", true)
	consumable = data.get("consumable", false)
	apply_on_signal = data.get("apply_on_signal", false)
	remove_on_signal = data.get("remove_on_signal", false)
	apply_signal = data.get("apply_signal", "")
	remove_signal = data.get("remove_signal", "")
	pause_on_apply_signal = data.get("pause_on_apply_signal", false)
	pause_on_remove_signal = data.get("pause_on_remove_signal", false)
	resume_on_apply_signal = data.get("resume_on_apply_signal", false)
	resume_on_remove_signal = data.get("resume_on_remove_signal", false)

	stack_mode = data.get("stack_mode", StackMode.MERGE_VALUES)
	max_stacks = data.get("max_stacks", -1)
	stack_source_id = data.get("stack_source_id", "")
	stack_count = data.get("stack_count", 1)
	
	enable_stack_decay = data.get("enable_stack_decay", false)
	stack_decay_interval = data.get("stack_decay_interval", 1.0)
	stack_decay_amount = data.get("stack_decay_amount", 1)
	stack_decay_min = data.get("stack_decay_min", 0)
	refresh_decay_on_stack = data.get("refresh_decay_on_stack", false)
	remove_on_zero_stacks = data.get("remove_on_zero_stacks", true)
	_stack_decay_timer = data.get("stack_decay_timer", 0.0)

	_connect_signals()

	if data.has("condition_class") and data["condition_class"] != "":
		condition = _instantiate_class(data["condition_class"])
		condition.from_dict(data["condition"])
		condition.init_stat(_parent)
		_connect_condition()

func _instantiate_class(class_type: String) -> Object:
	var global_classes = ProjectSettings.get_global_class_list()
	
	# Find the class in the global class list
	for gc in global_classes:
		if gc["class"] == class_type:
			# Load the script and instantiate it
			var script = load(gc["path"])
			if script:
				return script.new()
	
	# Fallback for built-in classes or if not found in global class list
	if class_type == "StatModifier":
		return StatModifier.new()
	elif class_type == "Condition":
		return Condition.new()
	else:
		push_warning("Unknown class type: %s, defaulting to null." % class_type)
		return null

## Gets the names of all stats affected by this modifier set.
## [return]: Dictionary of stat names to their Stat objects.
func get_affected_stats() -> Dictionary:
	var stats = {}
	for mod in _modifiers:
		stats[mod.get_stat_name()] = mod._stat
	return stats

## Gets a temporary version of the stats with all modifiers in this set applied.
## [return]: Dictionary of stat names to their temporary Stat objects.
func get_temp_applied_stats() -> Dictionary:
	var temp_stats := {}
	
	# First pass - initialize temp stats from valid modifiers
	for mod in _modifiers:
		var stat_name = mod.get_stat_name()

		if not mod.is_valid():
			if not temp_stats.has(stat_name):
				temp_stats[stat_name] = Stat.new()
			continue			
		
		# Only create new temp stat if we haven't seen this stat name yet
		if not temp_stats.has(stat_name):
			if _parent != null and mod._stat != null:
				temp_stats[stat_name] = mod._stat.duplicate(true)
	
	# Second pass - apply all modifiers to their respective stats
	for mod in _modifiers:	
		var stat_name = mod.get_stat_name()
		# Apply modifier to the temp stat
		mod._apply_stat_modifier(mod.get_type(), temp_stats[stat_name], mod.get_value())
	
	return temp_stats
	
## Simulates the effect of applying all modifiers in this set without changing the actual stats.
## [return]: Dictionary mapping stat names to their predicted changes:
##          { stat_name: { "old_value": float, "old_max": float, "value_diff": float, "max_diff": float } }
func simulate_effect() -> Dictionary:
	var result := {}
	var temp_stats = get_temp_applied_stats()
	
	for stat_name in temp_stats:
		var orig_stat = _parent.get_stat(stat_name)
		if orig_stat:
			result[stat_name] = orig_stat.get_difference_from(temp_stats[stat_name])
	
	return result
