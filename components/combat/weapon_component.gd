class_name WeaponComponent
extends TimedActionComponent

## Aliases all weapon-specific naming to base TimedActionComponent

## Enum aliases - reference parent enum directly
const FireMode = TimedActionComponent.ActionMode

## Property aliases
var base_fire_rate: float:
	get: return base_rate
	set(value): base_rate = value

var attack_speed: float:
	get: return rate_modifier
	set(value): rate_modifier = value

var attack_speed_scaling: float:
	get: return rate_modifier_scaling
	set(value): rate_modifier_scaling = value

var fire_mode: ActionMode:
	get: return action_mode
	set(value): action_mode = value

var fire_interval: float:
	get: return action_interval
	set(value): action_interval = value

var fire_on_start: bool:
	get: return execute_on_start
	set(value): execute_on_start = value

var is_firing: bool:
	get: return is_executing

var continuous_fire_progress: float:
	get: return get_continuous_progress()

var auto_fire: bool:
	get: return auto_execute
	set(value): auto_execute = value

## Signal aliases - re-emit base signals with weapon-specific names
signal fired()
signal continuous_fire_started()
signal continuous_fire_stopped()


func _init(
		_owner: Object = null,
		_base_fire_rate: float = 1.0,
		_attack_speed: float = 0.0,
		_attack_speed_scaling: float = 1.0,
) -> void:
	super(_owner, _base_fire_rate, _attack_speed, _attack_speed_scaling)
	
	# Connect base signals to weapon-specific signals
	executed.connect(func(): fired.emit())
	continuous_started.connect(func(): continuous_fire_started.emit())
	continuous_stopped.connect(func(): continuous_fire_stopped.emit())


## Method aliases
func fire() -> bool:
	return execute()


func can_fire() -> bool:
	return can_execute()

func stop_continuous_fire() -> void:
	stop_continuous_execution()


func cancel_continuous_fire() -> void:
	cancel_continuous_execution()


func is_continuous_firing() -> bool:
	return is_continuous_executing()


func get_continuous_fire_progress() -> float:
	return get_continuous_progress()


func set_auto_fire(enabled: bool) -> void:
	set_auto_execute(enabled)


func is_auto_fire_enabled() -> bool:
	return is_auto_execute_enabled()


func _execute_fire() -> void:
	pass

func _execute_action() -> void:
	_execute_fire()
