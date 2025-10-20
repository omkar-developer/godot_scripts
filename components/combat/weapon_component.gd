class_name WeaponComponent
extends RefCounted

enum FireMode {
	SINGLE,           # Fire once, then cooldown
	CONTINUOUS        # Fire repeatedly, stop based on condition
}

enum StopCondition {
	SHOT_COUNT,       # Stop after X shots (burst)
	DURATION,         # Stop after X seconds (channel/beam)
	MANUAL            # Stop when manually cancelled
}

var owner: Object = null
var auto_fire: bool = false
var cooldown_timer: float = 0.0

var base_fire_rate: float = 1.0
var attack_speed: float = 0.0
var attack_speed_scaling: float = 1.0

## Fire mode settings
var fire_mode: FireMode = FireMode.SINGLE
var stop_condition: StopCondition = StopCondition.SHOT_COUNT

## Continuous fire settings
var fire_interval: float = 0.1          # Time between shots in continuous mode
var max_shots: int = 3                  # For SHOT_COUNT mode
var max_duration: float = 1.0           # For DURATION mode

## Continuous fire options
var fire_on_start: bool = true          # Fire immediately when starting continuous fire
var cooldown_after_stop: bool = true    # Apply cooldown after continuous fire ends

## Runtime state
var is_firing: bool = false             # Currently in continuous fire
var continuous_timer: float = 0.0       # Time elapsed in current continuous fire
var shots_fired: int = 0                # Shots fired in current continuous fire
var fire_interval_timer: float = 0.0    # Timer for next fire in continuous mode

signal fired()
signal cooldown_ready()
signal continuous_fire_started()
signal continuous_fire_stopped()


func _init(
		_owner: Object = null,
		_base_fire_rate: float = 1.0,
		_attack_speed: float = 0.0,
		_attack_speed_scaling: float = 1.0,
) -> void:
	owner = _owner
	base_fire_rate = _base_fire_rate
	attack_speed = _attack_speed
	attack_speed_scaling = _attack_speed_scaling


func get_cooldown() -> float:
	var fire_rate = base_fire_rate + (attack_speed * attack_speed_scaling)
	return maxf(0.05, 1.0 / maxf(0.01, fire_rate))


func can_fire() -> bool:
	# Can't start new fire if already firing continuously
	if is_firing:
		return false
	
	return cooldown_timer >= get_cooldown()


func start_cooldown() -> void:
	cooldown_timer = 0.0


func update(delta: float) -> void:
	# Update continuous fire if active
	if is_firing:
		_update_continuous_fire(delta)
		return
	
	# Normal cooldown update
	var cooldown = get_cooldown()

	if cooldown_timer < cooldown:
		cooldown_timer += delta

		if cooldown_timer >= cooldown:
			cooldown_ready.emit()
	
	# Try to fire if auto-fire enabled and cooldown ready
	# Keep trying every frame until it succeeds
	if auto_fire and cooldown_timer >= cooldown:
		fire()


func fire() -> bool:
	if not can_fire():
		return false
	
	match fire_mode:
		FireMode.SINGLE:
			_execute_single_fire()
		FireMode.CONTINUOUS:
			_start_continuous_fire()
	
	return true


func _execute_single_fire() -> void:
	_execute_fire()
	start_cooldown()
	fired.emit()


func _start_continuous_fire() -> void:
	is_firing = true
	continuous_timer = 0.0
	shots_fired = 0
	fire_interval_timer = 0.0
	
	# Fire immediately if configured
	if fire_on_start:
		_execute_fire()
		shots_fired += 1
		fired.emit()
	
	continuous_fire_started.emit()


func _update_continuous_fire(delta: float) -> void:
	continuous_timer += delta
	fire_interval_timer += delta
	
	# Check if should fire next shot
	if fire_interval_timer >= fire_interval:
		fire_interval_timer = 0.0
		
		_execute_fire()
		shots_fired += 1
		fired.emit()
	
	# Check stop conditions
	if _should_stop_continuous_fire():
		stop_continuous_fire()


func _should_stop_continuous_fire() -> bool:
	match stop_condition:
		StopCondition.SHOT_COUNT:
			return shots_fired >= max_shots
		StopCondition.DURATION:
			return continuous_timer >= max_duration
		StopCondition.MANUAL:
			return false  # Only stops when manually called
	
	return false


func stop_continuous_fire() -> void:
	if not is_firing:
		return
	
	is_firing = false
	continuous_timer = 0.0
	shots_fired = 0
	fire_interval_timer = 0.0
	
	# Start cooldown if configured
	if cooldown_after_stop:
		start_cooldown()
	
	continuous_fire_stopped.emit()


func cancel_continuous_fire() -> void:
	stop_continuous_fire()


func _execute_fire() -> void:
	# Override in derived classes
	pass


func reset_cooldown() -> void:
	cooldown_timer = get_cooldown()
	cooldown_ready.emit()


func get_remaining_cooldown() -> float:
	var remaining = get_cooldown() - cooldown_timer
	return maxf(0.0, remaining)


func get_cooldown_progress() -> float:
	var cooldown = get_cooldown()
	if cooldown <= 0.0:
		return 1.0
	return clampf(cooldown_timer / cooldown, 0.0, 1.0)


func set_auto_fire(enabled: bool) -> void:
	auto_fire = enabled


func is_auto_fire_enabled() -> bool:
	return auto_fire


func set_owner(_owner: Object) -> void:
	owner = _owner


func get_owner() -> Object:
	return owner


func is_owner_valid() -> bool:
	return is_instance_valid(owner)


## Get continuous fire progress (0.0 to 1.0)
func get_continuous_fire_progress() -> float:
	if not is_firing:
		return 0.0
	
	match stop_condition:
		StopCondition.SHOT_COUNT:
			if max_shots <= 0:
				return 0.0
			return float(shots_fired) / float(max_shots)
		StopCondition.DURATION:
			if max_duration <= 0.0:
				return 0.0
			return continuous_timer / max_duration
		StopCondition.MANUAL:
			return 0.0  # No progress for manual mode
	
	return 0.0


## Check if currently firing continuously
func is_continuous_firing() -> bool:
	return is_firing
