extends StatModifierSet

## A timed version of StatModifierSet that can apply effects based on time intervals or total duration.
class_name StatModifierSetTimed

## Enum defining how this timed modifier set should be merged with another.
enum MergeType {
	NONE = 0,             ## No merging
	ADD_DURATION = 1,     ## Add duration values together
	ADD_VALUE = 2,        ## Add modifier values together
	ADD_INTERVAL = 4,     ## Add interval values together
	REDUCE_INTERVAL = 8,  ## Reduce interval values
	USE_FUNCTION = 16,    ## Use custom merge function
	RESET_DURATION = 32,  ## Reset duration timer
	RESET_INTERVAL_TIMER = 64, ## Reset interval timer
	DELETE = 128          ## Delete the modifier set
}

## Whether to apply the effect as soon as the modifier is initialized.
@export var apply_at_start := true

## Whether to remove the effect when the duration or total ticks are reached.
@export var remove_effect_on_finish := true

## Flags determining how this modifier set merges with others.
@export_flags("Add Duration", "Add Value", "Add Interval", "Reduce Interval", "Use Function", "Reset Duration", "Reset Interval Timer", "Delete") var merge_type := 3

@export_group("Timer")
## Time between effect applications (if 0, only applies once).
@export var interval := 0.0

## Minimum value for interval when merging.
@export var minimum_interval := 0.0

## Maximum value for interval when merging.
@export var maximum_interval := 3600.0

## Total duration for the effect (if 0, runs indefinitely or until ticks are done).
@export var duration := 0.0

## Total number of effect applications before stopping (-1 means unlimited).
@export var total_ticks:= -1

## Current time since creation.
var timer := 0.0

## Current time since last tick.
var tick_timer := 0.0

## Number of times the effect has been applied.
var ticks := 0

## Custom function for merging logic.
var merge_function: Callable

## Whether this modifier set is currently running.
var running := false

## Initialize a new timed modifier set with the given parameters.[br]
## [param modifier_name]: The name of this modifier set.[br]
## [param _process_every_frame]: Whether to process this modifier set every frame.[br]
## [param group]: The group to which this modifier set belongs.[br]
## [param _apply_at_start]: Whether to apply the effect as soon as the modifier is initialized.[br]
## [param _interval]: Time between effect applications.[br]
## [param _minimum_interval]: Minimum value for interval when merging.[br]
## [param _maximum_interval]: Maximum value for interval when merging.[br]
## [param _duration]: Total duration for the effect.[br]
## [param _total_ticks]: Total number of effect applications before stopping.[br]
## [param _merge_type]: Flags determining how this modifier set merges with others.[br]
## [param _remove_effect_on_finish]: Whether to remove the effect when the duration or total ticks are reached.[br]
## [param _merge_function]: Custom function for merging logic.
func _init(modifier_name := "", _process_every_frame := false, group := "", _apply_at_start := true, _interval := 0.0, _minimum_interval := 0.0, _maximum_interval := 3600.0, _duration := 0.0, _total_ticks := -1, _merge_type := 3, _remove_effect_on_finish := true, _merge_function := Callable()) -> void:
	super._init(modifier_name, _process_every_frame, group)
	apply_at_start = _apply_at_start
	interval = _interval
	minimum_interval = _minimum_interval
	maximum_interval = _maximum_interval
	duration = _duration
	total_ticks = _total_ticks
	merge_type = _merge_type
	if _apply_at_start: _apply = true
	remove_effect_on_finish = _remove_effect_on_finish
	_remove_all = remove_effect_on_finish
	merge_function = _merge_function
	_condition_apply_on_start = false
	_condition_pause_process = true

## Merges another modifier set into this one.[br]
## [param mod]: The modifier set to merge.
func merge_mod(mod: StatModifierSet) -> void:
	if not merge_enabled or merge_type == MergeType.NONE: return
	if mod is StatModifierSetTimed:
		if merge_type & MergeType.ADD_VALUE:
			super.merge_mod(mod)
		if merge_type & MergeType.ADD_DURATION:
			duration += mod.duration
		if merge_type & MergeType.ADD_INTERVAL:            
			interval = min(interval + mod.interval, maximum_interval)
		if merge_type & MergeType.REDUCE_INTERVAL:
			interval = max(interval - mod.interval, minimum_interval)
		if merge_type & MergeType.USE_FUNCTION:
			if not merge_function.is_null():
				merge_function.call(self, mod)
		if merge_type & MergeType.RESET_DURATION:
			timer = 0.0
		if merge_type & MergeType.RESET_INTERVAL_TIMER:
			tick_timer = 0.0
		if merge_type & MergeType.DELETE:
			delete()
	else:
		# For non-timed modifiers, just use the parent implementation for values
		if merge_type & MergeType.ADD_VALUE:
			super.merge_mod(mod)

## Process method called every frame when processing is enabled.[br]
## [param _delta]: Time since last frame.
func _process(_delta: float) -> void:
	# Call parent process first to handle condition checking
	super._process(_delta)
	
	if interval <= 0.0 and duration <= 0.0:
		delete()
		return
	
	if interval > 0.0:
		# Increase tick_timer by _delta but don't let it exceed the remaining time
		if duration > 0.0:
			tick_timer = min(tick_timer + _delta, duration - timer)
		else:
			tick_timer += _delta
			
		while tick_timer >= interval:
			tick_timer -= interval
			_apply_effect()
			ticks += 1
			if ticks >= total_ticks and total_ticks >= 0:
				delete()
				break

	if duration > 0.0:
		timer += _delta
		if timer >= duration:
			timer = 0.0
			delete()

## Creates a copy of this timed modifier set.[br]
## [return]: A new StatModifierSetTimed with the same properties.
func copy() -> StatModifierSetTimed:
	var new_copy = StatModifierSetTimed.new()
	new_copy.apply_at_start = apply_at_start
	new_copy.remove_effect_on_finish = remove_effect_on_finish
	new_copy.merge_type = merge_type
	new_copy.interval = interval
	new_copy.minimum_interval = minimum_interval
	new_copy.maximum_interval = maximum_interval
	new_copy.duration = duration
	new_copy.total_ticks = total_ticks
	new_copy.timer = timer
	new_copy.tick_timer = tick_timer
	new_copy.ticks = ticks
	new_copy.merge_function = merge_function
	new_copy.running = running
	
	# Copy base class properties
	for mod in _modifiers:
		new_copy._modifiers.append(mod.copy())
	new_copy._group = _group
	new_copy._modifier_name = _modifier_name
	new_copy.process = process
	new_copy.condition = condition.duplicate(true) if condition else null
	new_copy._condition_apply_on_start = _condition_apply_on_start
	new_copy._condition_pause_process = _condition_pause_process
	new_copy.apply_on_condition_change = apply_on_condition_change
	new_copy.remove_on_condition_change = remove_on_condition_change    
	new_copy.merge_enabled = merge_enabled
	new_copy._remove_all = _remove_all
	new_copy._marked_for_deletion = _marked_for_deletion
	
	return new_copy

## Returns a dictionary representation of this timed modifier set.[br]
## [return]: Dictionary containing all properties.
func to_dict() -> Dictionary:
	# Get the base class dictionary first
	var base_dict = super.to_dict()
	
	# Add timed-specific properties
	var timed_dict = {
		"apply_at_start": apply_at_start,
		"remove_effect_on_finish": remove_effect_on_finish,
		"merge_type": merge_type,
		"interval": interval,
		"minimum_interval": minimum_interval,
		"maximum_interval": maximum_interval,
		"duration": duration,
		"total_ticks": total_ticks,
		"timer": timer,
		"tick_timer": tick_timer,
		"ticks": ticks,
		"running": running,
	}

	base_dict.merge(timed_dict)
	
	# Merge dictionaries (timed properties take precedence)
	return base_dict

## Loads this timed modifier set from a dictionary.[br]
## [param data]: Dictionary containing properties to load.
func from_dict(data: Dictionary) -> void:
	# Call parent method to set base properties
	super.from_dict(data)
	
	# Load timed-specific properties
	apply_at_start = data.get("apply_at_start", true)
	remove_effect_on_finish = data.get("remove_effect_on_finish", true)
	merge_type = data.get("merge_type", 3)
	interval = data.get("interval", 0.0)
	minimum_interval = data.get("minimum_interval", 0.0)
	maximum_interval = data.get("maximum_interval", 3600.0)
	duration = data.get("duration", 0.0)
	total_ticks = data.get("total_ticks", -1.0)
	timer = data.get("timer", 0.0)
	tick_timer = data.get("tick_timer", 0.0)
	ticks = data.get("ticks", 0)
	running = data.get("running", false)

## Returns the class name of this modifier
func get_class_name() -> String:
	return "StatModifierSetTimed"
