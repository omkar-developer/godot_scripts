class_name TimedActionComponent
extends RefCounted

enum ActionMode {
	SINGLE,           ## Execute once, then cooldown
	CONTINUOUS        ## Execute repeatedly, stop based on condition
}

enum StopCondition {
	SHOT_COUNT,       ## Stop after X executions (burst)
	DURATION,         ## Stop after X seconds (channel/beam)
	MANUAL            ## Stop when manually cancelled
}

enum ContinuousUsesMode {
	PER_BURST,        ## Consume uses once per burst
	PER_EXECUTION     ## Consume uses for each execution in burst
}

var owner: Object = null
var auto_execute: bool = false
var cooldown_timer: float = 0.0
var paused: bool = false

var base_rate: float = 1.0
var rate_modifier: float = 0.0
var rate_modifier_scaling: float = 1.0
var cooldown_efficiency: float = 1.0      # Time multiplier: 1.0 = normal, 2.0 = double speed, 0.5 = half speed

## Action mode settings
var action_mode: ActionMode = ActionMode.SINGLE
var stop_condition: StopCondition = StopCondition.SHOT_COUNT

## Continuous action settings
var action_interval: float = 0.1          # Time between executions in continuous mode
var max_shots: int = 3                    # For SHOT_COUNT mode
var max_duration: float = 1.0             # For DURATION mode

## Continuous action options
var execute_on_start: bool = true         # Execute immediately when starting continuous action
var cooldown_after_stop: bool = true      # Apply cooldown after continuous action ends

## Usage/ammo system
var max_uses: int = -1                    # -1 = unlimited, 0+ = limited uses
var current_uses: int = -1                # Current remaining uses (-1 = unlimited)
var uses_per_execute: int = 1             # Cost per execution
var continuous_uses_mode: ContinuousUsesMode = ContinuousUsesMode.PER_BURST

## Runtime state
var is_executing: bool = false            # Currently in continuous execution
var continuous_timer: float = 0.0         # Time elapsed in current continuous execution
var shots_fired: int = 0                  # Executions in current continuous action
var action_interval_timer: float = 0.0    # Timer for next execution in continuous mode

signal executed()
signal cooldown_ready()
signal continuous_started()
signal continuous_stopped()
signal paused_changed(is_paused: bool)
signal uses_depleted()
signal uses_changed(current: int, maximum: int)


func _init(
		_owner: Object = null,
		_base_rate: float = 1.0,
		_rate_modifier: float = 0.0,
		_rate_modifier_scaling: float = 1.0,
) -> void:
	owner = _owner
	base_rate = _base_rate
	rate_modifier = _rate_modifier
	rate_modifier_scaling = _rate_modifier_scaling
	current_uses = max_uses


func get_cooldown() -> float:
	var rate = base_rate + (rate_modifier * rate_modifier_scaling)
	return maxf(0.05, 1.0 / maxf(0.01, rate))


func can_execute() -> bool:
	# Can't start new execution if already executing continuously
	if is_executing:
		return false
	
	# Check if paused
	if paused:
		return false
	
	# Check cooldown
	if cooldown_timer < get_cooldown():
		return false
	
	# Check uses
	if not has_uses():
		return false
	
	return true


func has_uses() -> bool:
	if max_uses < 0:  # Unlimited
		return true
	return current_uses >= uses_per_execute


func consume_uses(amount: int = 1) -> bool:
	if max_uses < 0:  # Unlimited
		return true
	
	if current_uses < amount:
		return false
	
	current_uses -= amount
	uses_changed.emit(current_uses, max_uses)
	
	if current_uses <= 0:
		uses_depleted.emit()
	
	return true


func refill_uses(amount: int) -> void:
	if max_uses < 0:  # Unlimited mode
		return
	
	current_uses = mini(current_uses + amount, max_uses)
	uses_changed.emit(current_uses, max_uses)


func set_max_uses(amount: int) -> void:
	max_uses = amount
	if max_uses >= 0:
		current_uses = max_uses
	else:
		current_uses = -1
	uses_changed.emit(current_uses, max_uses)


func start_cooldown() -> void:
	cooldown_timer = 0.0


func pause() -> void:
	if paused:
		return
	paused = true
	paused_changed.emit(true)


func resume() -> void:
	if not paused:
		return
	paused = false
	paused_changed.emit(false)


func update(delta: float) -> void:
	# Don't update timers when paused
	if paused:
		return
	
	# Apply cooldown efficiency (time scaling)
	var scaled_delta = delta * cooldown_efficiency
	
	# Update continuous execution if active
	if is_executing:
		_update_continuous_execution(scaled_delta)
		return
	
	# Normal cooldown update
	var cooldown = get_cooldown()

	if cooldown_timer < cooldown:
		cooldown_timer += scaled_delta

		if cooldown_timer >= cooldown:
			cooldown_ready.emit()
	
	# Try to execute if auto-execute enabled and cooldown ready
	# Keep trying every frame until it succeeds
	if auto_execute and cooldown_timer >= cooldown:
		execute()


func execute() -> bool:
	if not can_execute():
		return false
	
	match action_mode:
		ActionMode.SINGLE:
			_execute_single_action()
		ActionMode.CONTINUOUS:
			_start_continuous_execution()
	
	return true


func _execute_single_action() -> void:
	if not consume_uses(uses_per_execute):
		return
	
	_execute_action()
	start_cooldown()
	executed.emit()


func _start_continuous_execution() -> void:
	is_executing = true
	continuous_timer = 0.0
	shots_fired = 0
	action_interval_timer = 0.0
	
	# Consume uses for PER_BURST mode
	if continuous_uses_mode == ContinuousUsesMode.PER_BURST:
		if not consume_uses(uses_per_execute):
			is_executing = false
			return
	
	# Execute immediately if configured
	if execute_on_start:
		# Consume uses for PER_EXECUTION mode
		if continuous_uses_mode == ContinuousUsesMode.PER_EXECUTION:
			if not consume_uses(uses_per_execute):
				is_executing = false
				return
		
		_execute_action()
		shots_fired += 1
		executed.emit()
	
	continuous_started.emit()


func _update_continuous_execution(delta: float) -> void:
	continuous_timer += delta
	action_interval_timer += delta
	
	# Check if should execute next shot
	if action_interval_timer >= action_interval:
		action_interval_timer = 0.0
		
		# Check uses for PER_EXECUTION mode
		if continuous_uses_mode == ContinuousUsesMode.PER_EXECUTION:
			if not has_uses():
				stop_continuous_execution()
				return
			consume_uses(uses_per_execute)
		
		_execute_action()
		shots_fired += 1
		executed.emit()
	
	# Check stop conditions
	if _should_stop_continuous_execution():
		stop_continuous_execution()


func _should_stop_continuous_execution() -> bool:
	match stop_condition:
		StopCondition.SHOT_COUNT:
			return shots_fired >= max_shots
		StopCondition.DURATION:
			return continuous_timer >= max_duration
		StopCondition.MANUAL:
			return false  # Only stops when manually called
	
	return false


func stop_continuous_execution() -> void:
	if not is_executing:
		return
	
	is_executing = false
	continuous_timer = 0.0
	shots_fired = 0
	action_interval_timer = 0.0
	
	# Start cooldown if configured
	if cooldown_after_stop:
		start_cooldown()
	
	continuous_stopped.emit()


func cancel_continuous_execution() -> void:
	stop_continuous_execution()


func _execute_action() -> void:
	# Override in derived classes or connect to executed signal
	pass


func reset_cooldown() -> void:
	cooldown_timer = get_cooldown()
	cooldown_ready.emit()


func get_remaining_cooldown() -> float:
	var remaining = get_cooldown() - cooldown_timer
	return maxf(0.0, remaining)


func get_effective_remaining_cooldown() -> float:
	# Time remaining as experienced by player (accounts for cooldown efficiency)
	if cooldown_efficiency <= 0.0:
		return get_remaining_cooldown()
	return get_remaining_cooldown() / cooldown_efficiency


func get_cooldown_progress() -> float:
	var cooldown = get_cooldown()
	if cooldown <= 0.0:
		return 1.0
	return clampf(cooldown_timer / cooldown, 0.0, 1.0)


func set_auto_execute(enabled: bool) -> void:
	auto_execute = enabled


func is_auto_execute_enabled() -> bool:
	return auto_execute


func set_owner(_owner: Object) -> void:
	owner = _owner


func get_owner() -> Object:
	return owner


func is_owner_valid() -> bool:
	return is_instance_valid(owner)


## Get continuous execution progress (0.0 to 1.0)
func get_continuous_progress() -> float:
	if not is_executing:
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


## Check if currently executing continuously
func is_continuous_executing() -> bool:
	return is_executing


## Check if paused
func is_paused() -> bool:
	return paused


## Get uses info
func get_uses() -> int:
	return current_uses


func get_max_uses() -> int:
	return max_uses


func get_uses_percent() -> float:
	if max_uses < 0:
		return 1.0  # Unlimited
	if max_uses == 0:
		return 0.0
	return float(current_uses) / float(max_uses)


## Reset methods for flexible state management
func reset_timers() -> void:
	cooldown_timer = 0.0
	continuous_timer = 0.0
	action_interval_timer = 0.0
	shots_fired = 0


func reset_state() -> void:
	is_executing = false
	paused = false


func reset_uses() -> void:
	if max_uses >= 0:
		current_uses = max_uses
		uses_changed.emit(current_uses, max_uses)


func reset_all() -> void:
	reset_timers()
	reset_state()
	reset_uses()
