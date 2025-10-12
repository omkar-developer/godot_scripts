class_name LifetimeComponent
extends RefCounted

## Core lifetime component that auto-destroys entities after a duration.[br]
##[br]
## This component tracks elapsed time and destroys the owner when lifetime expires.[br]
## Useful for temporary entities like projectiles, effects, and spawned objects.[br]
## Requires manual update() calls each frame (typically from owner's _process).

## Reference to the entity that owns this component
var owner: Object = null

## Total lifetime duration in seconds
var lifetime: float = 5.0

## Time elapsed since creation or last reset
var elapsed: float = 0.0

## Whether to automatically destroy owner when lifetime ends
var auto_free: bool = true

## Whether lifetime tracking is paused
var paused: bool = false

## Emitted when lifetime expires.[br]
## [param owner]: The Object whose lifetime ended.
signal lifetime_ended(owner: Object)

## Emitted each frame with progress update.[br]
## [param progress]: Normalized progress (0.0 to 1.0).
signal lifetime_progress(progress: float)

## Constructor.[br]
## [param _owner]: The Object that owns this component.[br]
## [param _lifetime]: Duration in seconds before auto-destruction.
func _init(_owner: Object = null, _lifetime: float = 5.0) -> void:
	owner = _owner
	lifetime = _lifetime


## Update lifetime tracking (call this every frame).[br]
## [param delta]: Time elapsed since last update (in seconds).
func update(delta: float) -> void:
	if paused or lifetime <= 0.0:
		return
	
	elapsed += delta
	
	# Emit progress signal
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	lifetime_progress.emit(progress)
	
	# Check if lifetime expired
	if elapsed >= lifetime:
		_on_lifetime_expired()


## Reset lifetime counter to zero.
func reset() -> void:
	elapsed = 0.0


## Reset and set new lifetime duration.[br]
## [param new_lifetime]: New duration in seconds.
func reset_with_duration(new_lifetime: float) -> void:
	lifetime = new_lifetime
	reset()


## Get remaining lifetime.[br]
## [return]: Seconds remaining (0.0 if expired).
func get_remaining() -> float:
	return maxf(0.0, lifetime - elapsed)


## Get normalized progress (0.0 to 1.0).[br]
## [return]: Progress value (1.0 = expired).
func get_progress() -> float:
	if lifetime <= 0.0:
		return 1.0
	return clampf(elapsed / lifetime, 0.0, 1.0)


## Check if lifetime has expired.[br]
## [return]: true if elapsed >= lifetime.
func is_expired() -> bool:
	return elapsed >= lifetime


## Pause lifetime tracking.
func pause() -> void:
	paused = true


## Resume lifetime tracking.
func resume() -> void:
	paused = false


## Set whether to auto-free owner on expiration.[br]
## [param enabled]: true to enable auto-destruction.
func set_auto_free(enabled: bool) -> void:
	auto_free = enabled


## Set lifetime duration (doesn't reset elapsed time).[br]
## [param duration]: New lifetime in seconds.
func set_lifetime(duration: float) -> void:
	lifetime = duration


## Add time to remaining lifetime (extend duration).[br]
## [param additional_time]: Seconds to add.
func extend(additional_time: float) -> void:
	lifetime += additional_time


## Subtract time from remaining lifetime (reduce duration).[br]
## [param time_to_remove]: Seconds to subtract.
func reduce(time_to_remove: float) -> void:
	lifetime = maxf(0.0, lifetime - time_to_remove)
	
	# Check if now expired
	if elapsed >= lifetime:
		_on_lifetime_expired()


## Force immediate expiration (triggers lifetime_ended signal).
func expire_now() -> void:
	elapsed = lifetime
	_on_lifetime_expired()


## Internal: Handle lifetime expiration.
func _on_lifetime_expired() -> void:
	lifetime_ended.emit(owner)
	
	if auto_free and is_instance_valid(owner):
		# Check if owner has queue_free (Node method)
		if owner.has_method("queue_free"):
			owner.queue_free()
		# Fallback to free() if available
		elif owner.has_method("free"):
			owner.free()


## Get statistics as dictionary (for debugging/UI).[br]
## [return]: Dictionary with lifetime stats.
func get_stats() -> Dictionary:
	return {
		"lifetime": lifetime,
		"elapsed": elapsed,
		"remaining": get_remaining(),
		"progress": get_progress(),
		"is_expired": is_expired(),
		"paused": paused,
		"auto_free": auto_free
	}
