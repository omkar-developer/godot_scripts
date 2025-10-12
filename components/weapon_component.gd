class_name WeaponComponent
extends RefCounted

## Base weapon component that manages firing and cooldowns.[br]
##[br]
## Performance-optimized base class using cached values and signal-based updates.[br]
## Uses duck-typing in init: accepts stat names (String), Stat objects, or raw floats.[br]
## Override _execute_fire() in derived classes for weapon-specific behavior.

## Reference to the entity that owns this weapon
var owner: Object = null

## Enable/disable automatic firing
var auto_fire: bool = false

## Current cooldown timer (counts UP to cooldown target)
var cooldown_timer: float = 0.0

## Base fire rate - can be Stat object or float (use setter to update cached values)
var base_fire_rate:
	get:
		return _base_fire_rate
	set(value):
		_disconnect_stat(_base_fire_rate)
		_base_fire_rate = value
		_connect_stat(_base_fire_rate)
		_recalculate_cooldown()

## Owner's attack speed stat - can be Stat object or float (use setter to update)
var attack_speed:
	get:
		return _attack_speed
	set(value):
		_disconnect_stat(_attack_speed)
		_attack_speed = value
		_connect_stat(_attack_speed)
		_recalculate_cooldown()

## How much owner's attack speed affects this weapon (0.0 = none, 1.0 = full)
var attack_speed_scaling: float = 1.0:
	set(value):
		attack_speed_scaling = value
		_recalculate_cooldown()

## Internal: Actual stat storage
var _base_fire_rate = null
var _attack_speed = null

## Internal: Cached cooldown value (updated only when stats change)
var _cached_cooldown: float = 0.0

## Emitted when the weapon fires
signal fired()

## Emitted when cooldown finishes
signal cooldown_ready()


## Constructor with duck-typed parameters.[br]
## [param _owner]: The Object that owns this weapon.[br]
## [param _base_fire_rate]: Fire rate as float, Stat, or stat name String (default: 1.0).[br]
## [param _attack_speed]: Attack speed as float, Stat, or stat name String (default: "attack_speed").[br]
## [param _attack_speed_scaling]: How much attack speed affects weapon (default: 1.0).
func _init(
	_owner: Object = null,
	_base_fire_rate_param = 1.0,
	_attack_speed_param = "attack_speed",
	_attack_speed_scaling: float = 1.0
) -> void:
	owner = _owner
	attack_speed_scaling = _attack_speed_scaling
	
	# Resolve base_fire_rate (float, Stat, or stat name)
	_base_fire_rate = _resolve_stat(_base_fire_rate_param, null)
	_connect_stat(_base_fire_rate)
	
	# Resolve attack_speed (float, Stat, or stat name)
	_attack_speed = _resolve_stat(_attack_speed_param, owner)
	_connect_stat(_attack_speed)
	
	# Calculate initial cached cooldown
	_recalculate_cooldown()


## Resolve a stat parameter using duck-typing.[br]
## [param value]: Can be a float, Stat object, or stat name (String).[br]
## [param target_owner]: Object to get stat from if value is a String.[br]
## [return]: Resolved Stat object or float value.
func _resolve_stat(value, target_owner: Object):
	# If it's a String, try to get stat from owner
	if typeof(value) == TYPE_STRING:
		if target_owner != null:
			var stat = Stat.get_stat(target_owner, value)
			if stat != null:
				return stat
		return 0.0
	
	# Otherwise return as-is (Stat object or float)
	return value


## Helper function to get numeric value from Stat or float.[br]
## [param value]: Stat object or float.[br]
## [return]: Float value.
func _get_numeric_value(value) -> float:
	if value == null:
		return 0.0
	if typeof(value) == TYPE_OBJECT:
		return value.get_value()
	return float(value)


## Connect to a stat's value_changed signal if it's a Stat object.[br]
## [param stat]: Stat object or float value.
func _connect_stat(stat) -> void:
	if stat != null and typeof(stat) == TYPE_OBJECT:
		if not stat.value_changed.is_connected(_on_stat_changed):
			stat.value_changed.connect(_on_stat_changed)


## Disconnect from a stat's value_changed signal.[br]
## [param stat]: Stat object or float value.
func _disconnect_stat(stat) -> void:
	if stat != null and typeof(stat) == TYPE_OBJECT:
		if stat.value_changed.is_connected(_on_stat_changed):
			stat.value_changed.disconnect(_on_stat_changed)


## Callback when any connected stat changes.[br]
## Recalculates cached cooldown for performance.
func _on_stat_changed(_new_value, _new_max, _old_value, _old_max) -> void:
	_recalculate_cooldown()


## Recalculate and cache the cooldown value.[br]
## Formula: cooldown = 1.0 / (base_fire_rate + attack_speed * attack_speed_scaling).[br]
## Only called when stats change, not every frame!
func _recalculate_cooldown() -> void:
	# Get base fire rate (shots per second)
	var fire_rate := _get_numeric_value(_base_fire_rate)
	
	# Apply owner's attack speed with scaling: base + owner_stat * scaling
	var attack_speed_value := _get_numeric_value(_attack_speed)
	fire_rate = fire_rate + (attack_speed_value * attack_speed_scaling)
	
	# Convert fire rate to cooldown (minimum 0.05s)
	_cached_cooldown = maxf(0.05, 1.0 / maxf(0.01, fire_rate))


## Check if the weapon can fire.[br]
## [return]: true if cooldown is ready.
func can_fire() -> bool:
	return cooldown_timer >= _cached_cooldown


## Get the current cooldown duration.[br]
## Uses cached value for performance.[br]
## [return]: Current cooldown duration in seconds.
func get_cooldown() -> float:
	return _cached_cooldown


## Start the cooldown timer (resets to 0).
func start_cooldown() -> void:
	cooldown_timer = 0.0


## Update the weapon's cooldown timer.[br]
## Call this every frame from owner's _process or _physics_process.[br]
## [param delta]: Time elapsed since last frame.
func update(delta: float) -> void:
	# Count UP to cached cooldown (no recalculation per frame!)
	if cooldown_timer < _cached_cooldown:
		cooldown_timer += delta
		
		# Check if we just became ready
		if cooldown_timer >= _cached_cooldown:
			cooldown_ready.emit()
			
			# Auto-fire if enabled
			if auto_fire:
				fire()


## Attempt to fire the weapon.[br]
## [return]: true if weapon fired successfully, false if on cooldown.
func fire() -> bool:
	if not can_fire():
		return false
	
	_execute_fire()
	start_cooldown()
	fired.emit()
	return true


## Override this method in derived classes to implement weapon-specific behavior.[br]
## This is called when the weapon fires (e.g., spawn projectile, apply damage, etc.).[br]
## Damage handling should be implemented here in derived classes.
func _execute_fire() -> void:
	# Override in derived classes
	pass


## Reset cooldown (makes weapon ready to fire immediately).
func reset_cooldown() -> void:
	cooldown_timer = _cached_cooldown
	cooldown_ready.emit()


## Get remaining cooldown time.[br]
## [return]: Seconds remaining on cooldown, 0.0 if ready.
func get_remaining_cooldown() -> float:
	var remaining := _cached_cooldown - cooldown_timer
	return maxf(0.0, remaining)


## Get cooldown progress as percentage.[br]
## [return]: 0.0 (just fired) to 1.0 (ready to fire).
func get_cooldown_progress() -> float:
	if _cached_cooldown <= 0.0:
		return 1.0
	return clampf(cooldown_timer / _cached_cooldown, 0.0, 1.0)


## Enable or disable automatic firing.[br]
## [param enabled]: true to enable auto-fire, false to disable.
func set_auto_fire(enabled: bool) -> void:
	auto_fire = enabled


## Check if auto-fire is enabled.[br]
## [return]: true if auto-fire is enabled.
func is_auto_fire_enabled() -> bool:
	return auto_fire


## Set the owner Object.[br]
## [param _owner]: The Object that owns this weapon.
func set_owner(_owner: Object) -> void:
	owner = _owner


## Get the owner Object if still valid.[br]
## [return]: Owner Object if valid, null if freed.
func get_owner() -> Object:
	return owner


## Check if owner is still valid.[br]
## [return]: true if owner exists and hasn't been freed.
func is_owner_valid() -> bool:
	return is_instance_valid(owner)
