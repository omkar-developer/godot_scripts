class_name TargetingArea
extends Area2D

## Target selection and tracking component for Area2D-based detection.[br]
##[br]
## This component manages target detection through an Area2D and provides various[br]
## targeting priorities (closest, lowest HP, random, etc.). Supports both single and[br]
## multiple target tracking with configurable update modes for performance control.[br]
##[br]
## Update modes determine when targets are recalculated:[br]
## - MANUAL: Only when get_best_target(s) is called[br]
## - ON_ENTER: When any target enters detection[br]
## - ON_EXIT: When any target exits detection[br]
## - ON_TARGET_LOST: Only when a tracked target is lost (efficient for multi-target)[br]
## - AUTO: Periodic refresh via update(delta) with cooldown

## Target priority modes
enum Priority {
	CLOSEST,      ## Target nearest enemy by distance
	FARTHEST,     ## Target farthest enemy
	LOWEST_HP,    ## Target enemy with lowest health (requires get_health method)
	HIGHEST_HP,   ## Target enemy with highest health (requires get_health method)
	RANDOM,       ## Pick random target from valid list
	FIRST_SEEN,   ## Target first enemy that entered detection
	LAST_SEEN,    ## Target most recent enemy that entered detection
	CUSTOM        ## Use target_filter to determine best target (most flexibility)
}

## Update mode for automatic target recalculation
enum UpdateMode {
	MANUAL,         ## Only update when get_best_target(s) called manually
	ON_ENTER,       ## Recalculate when any target enters detection
	ON_EXIT,        ## Recalculate when any target exits detection
	ON_TARGET_LOST, ## Recalculate only when tracked target leaves (efficient)
	AUTO            ## Periodic refresh via update(delta) with cooldown
}

## Shape types for range detection
enum ShapeType {
	CIRCLE,      ## Circular detection range
	RECTANGLE,   ## Rectangular detection range
	CAPSULE,     ## Capsule detection range
	CUSTOM       ## Custom shape (manual scaling)
}

@export_group("Targeting Settings")
@export var target_priority: Priority = Priority.CLOSEST
@export var update_mode: UpdateMode = UpdateMode.ON_TARGET_LOST
@export var target_count: int = 1
@export var detection_range: float = 100.0:
	set(value):
		var old_range = detection_range
		detection_range = value
		if auto_update_shape:
			_update_collision_shape(detection_range)
		range_changed.emit(detection_range * range_multiplier, old_range * range_multiplier)

@export_group("Detection")
@export var detect_bodies: bool = true
@export var detect_areas: bool = true
@export var max_targets: int = 0

@export_group("Update Settings")
@export var auto_refresh_interval: float = 0.5
@export var auto_cleanup: bool = true

@export_group("Shape Settings")
@export var auto_update_shape: bool = true
@export var range_multiplier: float = 1.0

## List of currently valid targets in detection range
var valid_targets: Array[Node2D] = []

## Tracked best targets (size determined by target_count)
var tracked_targets: Array[Node2D] = []

## Custom filter/priority function for target validation and selection.[br]
## When priority = CUSTOM: func(targets: Array[Node2D]) -> Node2D (returns best target).[br]
## When priority != CUSTOM: func(target: Node2D) -> bool (validates if target is allowed).
var target_filter: Callable = Callable()

## Internal timer for AUTO update mode
var _refresh_timer: float = 0.0

## Reference to the detection shape
var collision_shape: CollisionShape2D = null

## Type of shape being used
var shape_type: ShapeType = ShapeType.CUSTOM

## Emitted when range value changes
signal range_changed(new_range: float, old_range: float)

## Emitted when a new target enters detection range and passes validation.[br]
## [param target]: The Node2D that entered detection.
signal target_found(target: Node2D)

## Emitted when a target leaves detection range or becomes invalid.[br]
## [param target]: The Node2D that left detection.
signal target_lost(target: Node2D)

## Emitted when tracked targets change (any update mode except MANUAL).[br]
## [param new_targets]: Array of currently tracked targets (size = target_count).
signal targets_changed(new_targets: Array[Node2D])

## Emitted when target list reaches max_targets limit.[br]
## [param rejected_target]: The target that couldn't be added.
signal target_limit_reached(rejected_target: Node2D)

# Fast-path optimization flags
var _can_use_single_fast_path: bool = false
var _can_use_multi_first_seen_fast_path: bool = false
var _can_use_multi_random_fast_path: bool = false

## Initialize component
func _enter_tree() -> void:
	if detect_bodies:
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
	if detect_areas:
		area_entered.connect(_on_area_entered)
		area_exited.connect(_on_area_exited)

## Initialize component
func _ready() -> void:
	_update_fast_path_flags()
	_detect_collision_shape()
	_scan_existing_targets()

## Internal: Update fast-path optimization flags based on current settings
func _update_fast_path_flags() -> void:
	var no_filter = not target_filter.is_valid()
	
	_can_use_single_fast_path = (
		target_count == 1 and 
		no_filter and 
		target_priority in [Priority.FIRST_SEEN, Priority.LAST_SEEN, Priority.RANDOM]
	)
	
	_can_use_multi_first_seen_fast_path = (
		target_count > 1 and 
		target_priority == Priority.FIRST_SEEN and 
		no_filter
	)
	
	_can_use_multi_random_fast_path = (
		target_count > 1 and 
		target_priority == Priority.RANDOM and 
		no_filter
	)


## Detect and configure collision shape
func _detect_collision_shape() -> void:	
	for child in get_children():
		if child is CollisionShape2D:
			collision_shape = child
			break
	
	if not collision_shape:
		push_warning("TargetingComponent: No CollisionShape2D found in detection_area")
		return
	
	var shape = collision_shape.shape
	if shape is CircleShape2D:
		shape_type = ShapeType.CIRCLE
	elif shape is RectangleShape2D:
		shape_type = ShapeType.RECTANGLE
	elif shape is CapsuleShape2D:
		shape_type = ShapeType.CAPSULE
	else:
		shape_type = ShapeType.CUSTOM
		push_warning(
			"TargetingComponent: Custom shape detected, use range_changed signal for manual scaling"
			)
	
	if auto_update_shape:
		_update_collision_shape(detection_range)


## Update collision shape size based on range
func _update_collision_shape(range_value: float) -> void:
	if not collision_shape or not collision_shape.shape:
		return
	
	var scaled_range = range_value * range_multiplier
	
	match shape_type:
		ShapeType.CIRCLE:
			var circle = collision_shape.shape as CircleShape2D
			circle.radius = scaled_range
		
		ShapeType.RECTANGLE:
			var rect = collision_shape.shape as RectangleShape2D
			rect.size = Vector2(scaled_range * 2, scaled_range * 2)
		
		ShapeType.CAPSULE:
			var capsule = collision_shape.shape as CapsuleShape2D
			capsule.radius = scaled_range
			capsule.height = scaled_range * 2

## Get current effective range (with multiplier)
func get_range() -> float:
	return detection_range * range_multiplier

## Set collision shape manually
func set_collision_shape(shape_node: CollisionShape2D) -> void:
	collision_shape = shape_node
	_detect_collision_shape()
	
	if auto_update_shape:
		_update_collision_shape(detection_range)

## Set range multiplier
func set_range_multiplier(multiplier: float, update_shape: bool = true) -> void:
	range_multiplier = multiplier
	
	if update_shape and auto_update_shape:
		_update_collision_shape(detection_range)

## Enable/disable automatic shape updates
func set_auto_update_shape(enabled: bool) -> void:
	auto_update_shape = enabled

## Force shape update
func force_update_shape() -> void:
	_update_collision_shape(detection_range)


## Get the best target (single target mode).[br]
## [param force_recalculate]: Force recalculation regardless of update mode.[br]
## [return]: The best target Node2D, or null if no valid targets.
func get_best_target(force_recalculate: bool = false) -> Node2D:
	if force_recalculate:
		_recalculate_targets()
	
	return tracked_targets[0] if not tracked_targets.is_empty() else null


## Get multiple best targets (multi-target mode).[br]
## [param force_recalculate]: Force recalculation regardless of update mode.[br]
## [return]: Array of best targets (size up to target_count).
func get_best_targets(force_recalculate: bool = false) -> Array[Node2D]:
	if force_recalculate:
		_recalculate_targets()
	
	return tracked_targets.duplicate()


## Update component (call in _process or _physics_process for AUTO mode).[br]
## [param delta]: Time elapsed since last frame.
func update(delta: float) -> void:
	if update_mode != UpdateMode.AUTO:
		return
	
	_refresh_timer += delta
	if _refresh_timer >= auto_refresh_interval:
		_refresh_timer = 0.0
		_recalculate_targets()


## Get all currently valid targets.[br]
## [return]: Array of valid target Nodes (copy of internal list).
func get_all_targets() -> Array[Node2D]:
	return valid_targets.duplicate()


## Get number of valid targets in detection range.[br]
## [return]: Count of targets.
func get_target_count() -> int:
	return valid_targets.size()


## Get number of currently tracked targets.[br]
## [return]: Count of tracked targets (up to target_count limit).
func get_tracked_count() -> int:
	return tracked_targets.size()


## Check if a specific Node2D is currently in detection range.[br]
## [param target]: The Node2D to check.[br]
## [return]: true if target is in valid_targets list.
func has_target(target: Node2D) -> bool:
	return valid_targets.has(target)


## Check if a specific Node2D is currently being tracked.[br]
## [param target]: The Node2D to check.[br]
## [return]: true if target is in tracked_targets list.
func is_tracking(target: Node2D) -> bool:
	return tracked_targets.has(target)


## Manually add a target (bypasses area detection).[br]
## [param target]: The Node2D to add as a target.[br]
## [return]: true if successfully added.
func add_target(target: Node2D) -> bool:
	if not is_instance_valid(target) or valid_targets.has(target):
		return false
	
	# Check custom filter (only for non-CUSTOM priority)
	if target_priority != Priority.CUSTOM and target_filter.is_valid():
		if not target_filter.call(target):
			return false
	
	# Check max targets limit
	if max_targets > 0 and valid_targets.size() >= max_targets:
		target_limit_reached.emit(target)
		return false
	
	valid_targets.append(target)
	target_found.emit(target)
	
	# Fast paths only auto-update in ON_ENTER, ON_EXIT, AUTO modes
	if update_mode != UpdateMode.MANUAL and update_mode != UpdateMode.ON_TARGET_LOST:
		# Fast path: Single target optimizations
		if _can_use_single_fast_path:
			_fast_path_single_target_entered(target)
			return true
		
		# Fast path: Multi-target FIRST_SEEN
		if _can_use_multi_first_seen_fast_path:
			_fast_path_multi_first_seen_entered(target)
			return true
		
		# Fast path: Multi-target RANDOM  
		if _can_use_multi_random_fast_path:
			_fast_path_multi_random_entered(target)
			return true
	
	# Trigger update based on mode
	if update_mode == UpdateMode.ON_ENTER or _should_update_on_entry():
		_recalculate_targets()
	
	return true


## Manually remove a target.[br]
## [param target]: The Node2D to remove from targets.[br]
## [return]: true if target was removed.
func remove_target(target: Node2D) -> bool:
	if valid_targets.has(target):
		valid_targets.erase(target)
		target_lost.emit(target)
		
		# Fast paths only auto-update in ON_ENTER, ON_EXIT, AUTO modes (not MANUAL)
		if update_mode != UpdateMode.MANUAL:
			# Fast path: Single target optimizations
			if _can_use_single_fast_path:
				_fast_path_single_target_exited(target)
				return true
			
			# Fast path: Multi-target FIRST_SEEN
			if _can_use_multi_first_seen_fast_path:
				_fast_path_multi_first_seen_exited(target)
				return true
			
			# Fast path: Multi-target RANDOM
			if _can_use_multi_random_fast_path:
				_fast_path_multi_random_exited(target)
				return true
		
		# Trigger update based on mode
		if update_mode == UpdateMode.ON_EXIT or _should_update_on_loss(target):
			_recalculate_targets()
		
		return true
	return false


## Clear all targets.[br]
## [param emit_signals]: Whether to emit target_lost for each target.
func clear_targets(emit_signals: bool = false) -> void:
	if emit_signals:
		for target in valid_targets:
			target_lost.emit(target)
	
	valid_targets.clear()
	tracked_targets.clear()
	targets_changed.emit(tracked_targets)


## Remove invalid/freed targets from list.[br]
## Called automatically if auto_cleanup is true.[br]
## [return]: Number of targets removed.
func clear_invalid_targets() -> int:
	return _cleanup_invalid_targets()


## Set custom target filter function.[br]
## For Priority.CUSTOM: func(targets: Array[Node2D]) -> Node2D (select best).[br]
## For other priorities: func(target: Node2D) -> bool (validate target).[br]
## [param filter_func]: Callable with appropriate signature.[br]
## [param revalidate_existing]: Whether to revalidate existing targets.
func set_target_filter(filter_func: Callable, revalidate_existing: bool = false) -> void:
	target_filter = filter_func
	_update_fast_path_flags()
	
	if revalidate_existing and target_filter.is_valid() and target_priority != Priority.CUSTOM:
		var to_remove: Array[Node2D] = []
		for target in valid_targets:
			if not target_filter.call(target):
				to_remove.append(target)
		
		for target in to_remove:
			remove_target(target)


## Clear the custom target filter.
func clear_target_filter() -> void:
	target_filter = Callable()
	_update_fast_path_flags()


## Change targeting priority mode.[br]
## [param new_priority]: New Priority enum value.
func set_target_priority(new_priority: Priority) -> void:
	if target_priority != new_priority:
		target_priority = new_priority
		_update_fast_path_flags()


## Change update mode.[br]
## [param new_mode]: New UpdateMode enum value.
func set_update_mode(new_mode: UpdateMode) -> void:
	update_mode = new_mode
	_refresh_timer = 0.0


## Change target count (switches between single/multi-target mode).[br]
## [param count]: Number of targets to track (1 = single, >1 = multiple).
func set_target_count(count: int) -> void:
	target_count = maxi(1, count)
	_update_fast_path_flags()


## Internal: Check if should update when target enters (for ON_TARGET_LOST mode).
func _should_update_on_entry() -> bool:
	# In ON_TARGET_LOST mode, update if we have fewer tracked targets than target_count
	return update_mode == UpdateMode.ON_TARGET_LOST and tracked_targets.size() < target_count


## Internal: Check if should update when target lost (for ON_TARGET_LOST mode).
func _should_update_on_loss(target: Node2D) -> bool:
	# In ON_TARGET_LOST mode, only update if the lost target was being tracked
	return update_mode == UpdateMode.ON_TARGET_LOST and tracked_targets.has(target)


#TODO: maybe ned optimizations
## Internal: Recalculate tracked targets based on priority.
func _recalculate_targets() -> void:
	# Clean invalid targets if auto-cleanup enabled
	if auto_cleanup:
		_cleanup_invalid_targets()
	
	if valid_targets.is_empty():
		if not tracked_targets.is_empty():
			tracked_targets.clear()
			targets_changed.emit(tracked_targets)
		return
	
	var new_tracked: Array[Node2D] = []
	
	# Check for fast paths first
	if _can_use_single_fast_path:
		new_tracked = _fast_path_get_single_target()
	elif _can_use_multi_first_seen_fast_path:
		new_tracked = _fast_path_get_multi_first_seen()
	elif _can_use_multi_random_fast_path:
		new_tracked = _fast_path_get_multi_random()
	else:
		# Fall back to original logic
		if target_count == 1:
			var best = _get_single_best_target()
			if best:
				new_tracked.append(best)
		else:
			new_tracked = _get_multiple_best_targets()
	
	# Check if targets actually changed
	if _targets_differ(tracked_targets, new_tracked):
		tracked_targets = new_tracked
		targets_changed.emit(tracked_targets)


## Internal: Check if two target arrays differ.
func _targets_differ(old: Array[Node2D], new: Array[Node2D]) -> bool:
	if old.size() != new.size():
		return true
	
	for i in range(old.size()):
		if old[i] != new[i]:
			return true
	
	return false


## Internal: Get single best target based on priority.
func _get_single_best_target() -> Node2D:
	match target_priority:
		Priority.CLOSEST:
			return _get_closest_target()
		Priority.FARTHEST:
			return _get_farthest_target()
		Priority.LOWEST_HP:
			return _get_lowest_hp_target()
		Priority.HIGHEST_HP:
			return _get_highest_hp_target()
		Priority.RANDOM:
			return valid_targets.pick_random()
		Priority.FIRST_SEEN:
			return valid_targets[0]
		Priority.LAST_SEEN:
			return valid_targets[-1]
		Priority.CUSTOM:
			if target_filter.is_valid():
				return target_filter.call(valid_targets.duplicate())
			
			push_warning("TargetingComponent: CUSTOM priority requires target_filter to be set")
			return valid_targets[0] if not valid_targets.is_empty() else null
	
	return null


## Internal: Get multiple best targets based on priority.
func _get_multiple_best_targets() -> Array[Node2D]:
	var sorted_targets: Array[Node2D] = valid_targets.duplicate()
	
	# Sort based on priority
	match target_priority:
		Priority.CLOSEST:
			sorted_targets = _sort_by_distance(sorted_targets, true)
		Priority.FARTHEST:
			sorted_targets = _sort_by_distance(sorted_targets, false)
		Priority.LOWEST_HP:
			sorted_targets = _sort_by_health(sorted_targets, true)
		Priority.HIGHEST_HP:
			sorted_targets = _sort_by_health(sorted_targets, false)
		Priority.RANDOM:
			sorted_targets.shuffle()
		Priority.CUSTOM:
			if target_filter.is_valid():
				# For custom multi-target, user must return array
				var custom_result = target_filter.call(sorted_targets)
				var filtered: Array[Node2D] = []
				for t in custom_result:
					if is_instance_valid(t):
						filtered.append(t)
				sorted_targets = filtered

	
	# Return up to target_count targets
	if sorted_targets.size() > target_count:
		sorted_targets.resize(target_count)
	
	return sorted_targets


## Internal: Handle body entering detection area.
func _on_body_entered(body: Node2D) -> void:
	_handle_target_entered(body)


## Internal: Handle area entering detection area.
func _on_area_entered(area: Node2D) -> void:
	_handle_target_entered(area)


## Internal: Handle body exiting detection area.
func _on_body_exited(body: Node2D) -> void:
	_handle_target_exited(body)


## Internal: Handle area exiting detection area.
func _on_area_exited(area: Node2D) -> void:
	_handle_target_exited(area)


## Internal: Common logic for target entering.
func _handle_target_entered(target: Node2D) -> void:
	# Avoid duplicates
	if valid_targets.has(target):
		return
	
	# Check custom filter (only for non-CUSTOM priority)
	if target_priority != Priority.CUSTOM and target_filter.is_valid():
		if not target_filter.call(target):
			return
	
	# Check max targets limit
	if max_targets > 0 and valid_targets.size() >= max_targets:
		target_limit_reached.emit(target)
		return
	
	valid_targets.append(target)
	target_found.emit(target)
	
	# Fast paths only auto-update in ON_ENTER, ON_EXIT, AUTO modes
	if update_mode != UpdateMode.MANUAL and update_mode != UpdateMode.ON_TARGET_LOST:
		# Fast path: Single target optimizations
		if _can_use_single_fast_path:
			_fast_path_single_target_entered(target)
			return
		
		# Fast path: Multi-target FIRST_SEEN
		if _can_use_multi_first_seen_fast_path:
			_fast_path_multi_first_seen_entered(target)
			return
		
		# Fast path: Multi-target RANDOM  
		if _can_use_multi_random_fast_path:
			_fast_path_multi_random_entered(target)
			return
	
	# Trigger update based on mode
	if update_mode == UpdateMode.ON_ENTER or _should_update_on_entry():
		_recalculate_targets()


## Internal: Common logic for target exiting.
func _handle_target_exited(target: Node2D) -> void:
	if valid_targets.has(target):
		valid_targets.erase(target)
		target_lost.emit(target)
		
		# Fast paths only auto-update in ON_ENTER, ON_EXIT, AUTO modes (not MANUAL)
		if update_mode != UpdateMode.MANUAL:
			# Fast path: Single target optimizations
			if _can_use_single_fast_path:
				_fast_path_single_target_exited(target)
				return
			
			# Fast path: Multi-target FIRST_SEEN
			if _can_use_multi_first_seen_fast_path:
				_fast_path_multi_first_seen_exited(target)
				return
			
			# Fast path: Multi-target RANDOM
			if _can_use_multi_random_fast_path:
				_fast_path_multi_random_exited(target)
				return
		
		# Trigger update based on mode
		if update_mode == UpdateMode.ON_EXIT or _should_update_on_loss(target):
			_recalculate_targets()


## Internal: Scan for targets already in detection area (called when area changes).
func _scan_existing_targets() -> void:
	if detect_bodies:
		var bodies = get_overlapping_bodies()
		for body in bodies:
			_handle_target_entered(body)
	
	if detect_areas:
		var areas = get_overlapping_areas()
		for area in areas:
			_handle_target_entered(area)


## Internal: Find closest target by distance.
func _get_closest_target() -> Node2D:
	var closest: Node2D = null
	var min_dist = INF
	
	for target in valid_targets:
		if not is_instance_valid(target) or not target is Node2D:
			continue
		
		var target_node = target as Node2D
		var dist = global_position.distance_squared_to(target_node.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = target_node
	
	return closest

## Internal: Find farthest target by distance.
func _get_farthest_target() -> Node2D:
	var farthest: Node2D = null
	var max_dist = -INF
	
	for target in valid_targets:
		if not is_instance_valid(target):
			continue
		
		var dist = global_position.distance_squared_to(target.global_position)
		if dist > max_dist:
			max_dist = dist
			farthest = target
	
	return farthest


## Internal: Find target with lowest HP.
func _get_lowest_hp_target() -> Node2D:
	var lowest: Node2D = null
	var min_hp = INF
	
	for target in valid_targets:
		if not is_instance_valid(target):
			continue
		
		var hp = _get_target_health(target)
		if hp < 0.0:  # Target has no health method
			continue
		
		if hp < min_hp:
			min_hp = hp
			lowest = target
	
	return lowest


## Internal: Find target with highest HP.
func _get_highest_hp_target() -> Node2D:
	var highest: Node2D = null
	var max_hp = -INF
	
	for target in valid_targets:
		if not is_instance_valid(target):
			continue
		
		var hp = _get_target_health(target)
		if hp < 0.0:  # Target has no health method
			continue
		
		if hp > max_hp:
			max_hp = hp
			highest = target
	
	return highest


## Internal: Sort targets by distance.
func _sort_by_distance(targets: Array[Node2D], ascending: bool) -> Array[Node2D]:
	targets.sort_custom(func(a, b):
		var dist_a = global_position.distance_squared_to(a.global_position)
		var dist_b = global_position.distance_squared_to(b.global_position)
		return dist_a < dist_b if ascending else dist_a > dist_b
	)
	return targets


## Internal: Sort targets by health.
func _sort_by_health(targets: Array[Node2D], ascending: bool) -> Array[Node2D]:
	var filtered_targets: Array[Node2D] = []
	
	# Filter out targets without health
	for target in targets:
		if _get_target_health(target) >= 0.0:
			filtered_targets.append(target)
	
	filtered_targets.sort_custom(func(a, b):
		var hp_a = _get_target_health(a)
		var hp_b = _get_target_health(b)
		return hp_a < hp_b if ascending else hp_a > hp_b
	)
	
	return filtered_targets


## Internal: Get health from target (duck typing).[br]
## [return]: Health value or -1.0 if target has no health method.
func _get_target_health(target: Node2D) -> float:
	# Try get_health() method first
	if target.has_method("get_health"):
		return target.get_health()
	
	# Try health property
	if "health" in target:
		var health_prop = target.get("health")
		if health_prop is float or health_prop is int:
			return float(health_prop)
		return health_prop.get_value()
	
	return -1.0


## Internal: Remove invalid targets from list.[br]
## [return]: Number of targets removed.
func _cleanup_invalid_targets() -> int:
	var removed = 0
	var i = valid_targets.size() - 1
	
	while i >= 0:
		var target = valid_targets[i]
		if not is_instance_valid(target):
			valid_targets.remove_at(i)
			target_lost.emit(target)
			removed += 1
		i -= 1
	
	# Also clean tracked targets
	i = tracked_targets.size() - 1
	while i >= 0:
		var target = tracked_targets[i]
		if not is_instance_valid(target):
			tracked_targets.remove_at(i)
			removed += 1
		i -= 1
	
	return removed

# ==============================================================================
# FAST PATH OPTIMIZATIONS
# ==============================================================================

## Fast path: Handle single target entry for FIRST_SEEN, LAST_SEEN, RANDOM
func _fast_path_single_target_entered(target: Node2D) -> void:
	if auto_cleanup: _cleanup_invalid_targets()

	var old_tracked = tracked_targets.duplicate()
	
	match target_priority:
		Priority.FIRST_SEEN:
			# Track first target and never switch until it exits
			if tracked_targets.is_empty():
				tracked_targets = [target]
		
		Priority.LAST_SEEN:
			# Always replace with newest target
			tracked_targets = [target]
		
		Priority.RANDOM:
			if tracked_targets.is_empty():
				tracked_targets = [target]
			else:
				# 50% chance to replace
				if randf() < 0.5:
					tracked_targets = [target]
	
	# Emit signal if targets changed
	if _targets_differ(old_tracked, tracked_targets):
		targets_changed.emit(tracked_targets)


## Fast path: Handle single target exit for FIRST_SEEN, LAST_SEEN, RANDOM
func _fast_path_single_target_exited(target: Node2D) -> void:
	if auto_cleanup: _cleanup_invalid_targets()

	var old_tracked = tracked_targets.duplicate()
	
	# If the exited target was being tracked, update tracked targets
	if tracked_targets.size() == 1 and tracked_targets[0] == target:
		match target_priority:
			Priority.FIRST_SEEN:
				# Take the next first target (if any)
				tracked_targets = [valid_targets[0]] if not valid_targets.is_empty() else []
			
			Priority.LAST_SEEN:
				# Take the last target (if any)
				tracked_targets = [valid_targets[-1]] if not valid_targets.is_empty() else []
			
			Priority.RANDOM:
				# Pick a new random target (if any)
				if not valid_targets.is_empty():
					tracked_targets = [valid_targets.pick_random()]
				else:
					tracked_targets = []
	
	# Emit signal if targets changed
	if _targets_differ(old_tracked, tracked_targets):
		targets_changed.emit(tracked_targets)


## Fast path: Get single target for manual recalculation
func _fast_path_get_single_target() -> Array[Node2D]:
	if valid_targets.is_empty():
		return []
	
	match target_priority:
		Priority.FIRST_SEEN:
			return [valid_targets[0]]
		Priority.LAST_SEEN:
			return [valid_targets[-1]]
		Priority.RANDOM:
			return [valid_targets.pick_random()]
	
	return []


## Fast path: Handle multi-target FIRST_SEEN entry
func _fast_path_multi_first_seen_entered(_target: Node2D) -> void:
	if auto_cleanup: _cleanup_invalid_targets()

	var old_tracked = tracked_targets.duplicate()
	
	# Simply take the first target_count targets
	if tracked_targets.size() < target_count:
		tracked_targets = valid_targets.slice(0, min(target_count, valid_targets.size()))
	
	# Emit signal if targets changed
	if _targets_differ(old_tracked, tracked_targets):
		targets_changed.emit(tracked_targets)


## Fast path: Handle multi-target FIRST_SEEN exit
func _fast_path_multi_first_seen_exited(target: Node2D) -> void:
	if auto_cleanup: _cleanup_invalid_targets()

	var old_tracked = tracked_targets.duplicate()
	
	# Remove the target if it was tracked
	if tracked_targets.has(target):
		tracked_targets.erase(target)
	
	# Fill any empty slots with the next available targets
	if tracked_targets.size() < target_count and valid_targets.size() > tracked_targets.size():
		var start_index = tracked_targets.size()
		var end_index = min(valid_targets.size(), target_count)
		for i in range(start_index, end_index):
			tracked_targets.append(valid_targets[i])
	
	# Emit signal if targets changed
	if _targets_differ(old_tracked, tracked_targets):
		targets_changed.emit(tracked_targets)


## Fast path: Get multi-target FIRST_SEEN for manual recalculation
func _fast_path_get_multi_first_seen() -> Array[Node2D]:
	return valid_targets.slice(0, min(target_count, valid_targets.size()))


## Fast path: Handle multi-target RANDOM entry
func _fast_path_multi_random_entered(target: Node2D) -> void:
	if auto_cleanup: _cleanup_invalid_targets()

	var old_tracked = tracked_targets.duplicate()
	
	if tracked_targets.size() < target_count:
		# Add new target if we have room
		tracked_targets.append(target)
	else:
		# Randomly decide whether to replace an existing target
		var replace_index = randi() % target_count
		tracked_targets[replace_index] = target
	
	# Emit signal if targets changed
	if _targets_differ(old_tracked, tracked_targets):
		targets_changed.emit(tracked_targets)


## Fast path: Handle multi-target RANDOM exit
func _fast_path_multi_random_exited(target: Node2D) -> void:
	if auto_cleanup: _cleanup_invalid_targets()

	var old_tracked = tracked_targets.duplicate()
	
	# Remove the target if it was tracked
	if tracked_targets.has(target):
		tracked_targets.erase(target)
		
		# If we have room and available targets, add a new random one
		if tracked_targets.size() < target_count and not valid_targets.is_empty():
			# Get targets not currently tracked
			var available_targets = []
			for t in valid_targets:
				if not tracked_targets.has(t):
					available_targets.append(t)
			
			if not available_targets.is_empty():
				tracked_targets.append(available_targets.pick_random())
	
	# Emit signal if targets changed
	if _targets_differ(old_tracked, tracked_targets):
		targets_changed.emit(tracked_targets)


## Fast path: Get multi-target RANDOM for manual recalculation
func _fast_path_get_multi_random() -> Array[Node2D]:
	if valid_targets.size() <= target_count:
		return valid_targets.duplicate()
	
	# Select target_count unique random elements without shuffling entire array
	var result: Array[Node2D] = []
	var available_indices = range(valid_targets.size())
	
	for i in range(target_count):
		var random_index = randi() % available_indices.size()
		var selected_index = available_indices[random_index]
		result.append(valid_targets[selected_index])
		available_indices.remove_at(random_index)
	
	return result
