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

func merge_mod(mod: StatModifierSet) -> void:
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
    if _marked_for_deletion or not process:
        return
    
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