extends StatModifierSet

class_name StatModifierSetTimed

enum MergeType {
    NONE = 0,
    ADD_DURATION = 1,
    ADD_VALUE = 2,
    ADD_INTERVAL = 4,
    REDUCE_INTERVAL = 8,
    USE_FUNCTION = 16,
    RESET_DURATION = 32,
    RESET_INTERVAL_TIMER = 64,
    DELETE = 128
}

@export var apply_at_start := true
@export var remove_effect_on_finish := true
@export_flags("Add Duration", "Add Value", "Add Interval", "Reduce Interval", "Use Function", "Reset Duration", "Reset Interval Timer", "Delete") var merge_type := 3

@export_group("Timer")
@export var interval := 0.0
@export var minimum_interval := 0.0
@export var maximum_interval := 3600.0
@export var duration := 0.0
@export var total_ticks:= -1.0

var timer := 0.0
var tick_timer := 0.0
var ticks := 0
var merge_function: Callable
var running := false

func _init(modifier_name := "", _process_every_frame := false, group := "", _apply_at_start := true, _interval := 0.0, _minimum_interval := 0.0, _maximum_interval := 3600.0, _duration := 0.0, _total_ticks := 0, _merge_type := 3, _remove_effect_on_finish := true, _merge_function := Callable()) -> void:
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

func merge_mod(mod: StatModifierSet) -> void:
    if not merge_enabled or merge_type == MergeType.NONE: return
    if mod is StatModifierSetTimed:
        if merge_type & MergeType.ADD_VALUE:
            super.merge_mod(mod)
        if merge_type & MergeType.ADD_DURATION:
            duration += mod.duration
        if merge_type & MergeType.ADD_INTERVAL:            
            interval += min(interval + mod.interval, maximum_interval)
        if merge_type & MergeType.REDUCE_INTERVAL:
            interval -= max(interval - mod.interval, minimum_interval)
        if merge_type & MergeType.USE_FUNCTION:
            if not merge_function.is_null():
                merge_function.call(self, mod)
        if merge_type & MergeType.RESET_DURATION:
            timer = 0.0
        if merge_type & MergeType.RESET_INTERVAL_TIMER:
            tick_timer = 0.0
        if merge_type & MergeType.DELETE:
            delete()

func _process(_delta: float) -> void:
    if interval <= 0.0 and duration <= 0.0:
        delete()
        return

    if interval > 0.0:
        if ticks >= total_ticks and total_ticks >= 0:
            delete()
        tick_timer += _delta
        if tick_timer >= interval:
            tick_timer -= interval
            _apply_effect()
            ticks += 1

    if duration > 0.0:
        timer += _delta
        if timer >= duration:
            timer = 0.0
            delete()

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
    for mod in _modifiers:
        new_copy.modifiers.append(mod.copy())
    new_copy.group = _group
    new_copy.modifier_name = _modifier_name
    new_copy.process = process
    new_copy.condition = condition.duplicate(true)
    new_copy._condition_apply_on_start = _condition_apply_on_start
    new_copy._condition_pause_process = _condition_pause_process
    new_copy.apply_on_condition_change = apply_on_condition_change
    new_copy.remove_on_condition_change = remove_on_condition_change    
    new_copy.merge_enabled = merge_enabled
    new_copy._remove_all = _remove_all
    new_copy._marked_for_deletion = _marked_for_deletion
    return new_copy

func to_dict() -> Dictionary:
    return {
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
        "merge_function": merge_function,
        "running": running,
        "modifiers": _modifiers.map(func(m): return m.to_dict()),
        "modifier_name": _modifier_name,
        "group": _group,
        "process": process,
        "condition": condition.to_dict() if condition else null
    }

func from_dict(data: Dictionary) -> void:
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
    merge_function = data.get("merge_function", Callable())
    running = data.get("running", false)
    _modifiers = data.get("modifiers", []).map(
        func(m_data): 
            var m = StatModifier.new()
            m.from_dict(m_data)
            return m
    )
    _modifier_name = data.get("modifier_name", "")
    _group = data.get("group", "")
    process = data.get("process", false)
    if data.get("condition", null):
        condition = Condition.new()
        condition.from_dict(data.get("condition", null))
    else:
        condition = null

