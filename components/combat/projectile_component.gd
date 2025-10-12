class_name ProjectileComponent
extends RefCounted

## Core projectile component that handles pierce mechanics and hit behavior.[br]
##[br]
## This component tracks hits and determines when a projectile should be destroyed.[br]
## Supports pierce counts, hit tracking, and automatic destruction on collision.[br]
## Works with any Object, but requires owner to have queue_free() for auto-destruction.

## Reference to the entity that owns this component
var owner: Object = null

## Maximum number of targets this projectile can pierce (-1 = infinite)
var max_pierce: int = 0

## Number of targets hit so far
var hits: int = 0

## Whether the projectile should be destroyed when hitting terrain/walls
var destroy_on_terrain: bool = true

## Whether the projectile should be destroyed when max pierce is reached
var auto_destroy: bool = true

## List of already-hit targets (to prevent double-hitting)
var hit_targets: Array = []

## Whether to track hit targets (disable for performance if not needed)
var track_hit_targets: bool = true

## Emitted when projectile hits a target.[br]
## [param target]: The Object that was hit.[br]
## [param hits_remaining]: Number of pierces remaining (-1 if infinite).
signal target_hit(target: Object, hits_remaining: int)

## Emitted when projectile should be destroyed (max pierce reached).
signal should_destroy()

## Emitted when projectile hits terrain/walls.
signal terrain_hit()

## Constructor.[br]
## [param _owner]: The Object that owns this component (projectile).[br]
## [param _max_pierce]: Maximum pierce count (-1 for infinite, 0 for destroy on first hit).
func _init(_owner: Object = null, _max_pierce: int = 0) -> void:
	owner = _owner
	max_pierce = _max_pierce


## Register a hit on a target.[br]
## [param target]: The Object that was hit.[br]
## [return]: true if hit was registered, false if already hit or pierce exhausted.
func register_hit(target: Object) -> bool:
	# Check if target already hit (if tracking enabled)
	if track_hit_targets and _was_already_hit(target):
		return false
	
	# Check if pierce exhausted (but not infinite)
	if max_pierce >= 0 and hits >= max_pierce + 1:
		return false
	
	# Register the hit
	hits += 1
	
	if track_hit_targets and is_instance_valid(target):
		hit_targets.append(target)
	
	# Calculate remaining hits
	var hits_remaining := -1 if max_pierce < 0 else (max_pierce + 1 - hits)
	
	# Emit signal
	target_hit.emit(target, hits_remaining)
	
	# Check if should destroy
	if _should_destroy_on_hit():
		should_destroy.emit()
		if auto_destroy:
			_destroy_owner()
		return true
	
	return true


## Register a terrain/wall hit.[br]
## [return]: true if projectile should be destroyed.
func register_terrain_hit() -> bool:
	terrain_hit.emit()
	
	if destroy_on_terrain:
		should_destroy.emit()
		if auto_destroy:
			_destroy_owner()
		return true
	
	return false


## Check if projectile can pierce more targets.[br]
## [return]: true if more hits are allowed.
func can_hit_more() -> bool:
	if max_pierce < 0:
		return true  # Infinite pierce
	return hits < max_pierce + 1


## Check if a specific target can be hit (not already in hit list).[br]
## [param target]: The Object to check.[br]
## [return]: true if target can be hit.
func can_hit_target(target: Object) -> bool:
	if not track_hit_targets:
		return can_hit_more()
	
	return can_hit_more() and not _was_already_hit(target)


## Get number of remaining pierces.[br]
## [return]: Remaining pierce count, or -1 if infinite.
func get_remaining_pierces() -> int:
	if max_pierce < 0:
		return -1
	return maxi(0, max_pierce + 1 - hits)


## Reset hit tracking (clear hit list and counter).
func reset() -> void:
	hits = 0
	hit_targets.clear()


## Set pierce count.[br]
## [param pierce_count]: New max pierce (-1 for infinite, 0 for single hit).
func set_pierce_count(pierce_count: int) -> void:
	max_pierce = pierce_count


## Enable/disable terrain destruction.[br]
## [param enabled]: Whether to destroy on terrain hit.
func set_destroy_on_terrain(enabled: bool) -> void:
	destroy_on_terrain = enabled


## Enable/disable hit target tracking.[br]
## [param enabled]: Whether to prevent double-hitting same target.
func set_track_hit_targets(enabled: bool) -> void:
	track_hit_targets = enabled
	if not enabled:
		hit_targets.clear()


## Internal: Check if target was already hit.
func _was_already_hit(target: Object) -> bool:
	if not track_hit_targets:
		return false
	
	# Clean up any invalid references
	hit_targets = hit_targets.filter(func(t): return is_instance_valid(t))
	
	return target in hit_targets


## Internal: Check if projectile should be destroyed after hit.
func _should_destroy_on_hit() -> bool:
	if max_pierce < 0:
		return false  # Infinite pierce, never destroy
	return hits >= max_pierce + 1


## Internal: Destroy the owner entity.
func _destroy_owner() -> void:
	if not is_instance_valid(owner):
		return
	
	# Check if owner has queue_free (Node method)
	if owner.has_method("queue_free"):
		owner.queue_free()
	# Fallback to free() if available
	elif owner.has_method("free"):
		owner.free()


## Get statistics as dictionary (for debugging/UI).[br]
## [return]: Dictionary with hit stats.
func get_stats() -> Dictionary:
	return {
		"hits": hits,
		"max_pierce": max_pierce,
		"remaining": get_remaining_pierces(),
		"can_hit_more": can_hit_more(),
		"hit_targets_count": hit_targets.size()
	}
