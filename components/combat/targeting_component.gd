class_name TargetingComponent
extends RefCounted

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

## Reference to the entity that owns this component (can be any Object)
var owner: Object = null

## Area2D used for target detection (connects to body/area entered/exited signals)
var detection_area: Area2D = null

## Current targeting priority mode
var priority: Priority = Priority.CLOSEST

## Update mode for automatic target recalculation
var update_mode: UpdateMode = UpdateMode.ON_TARGET_LOST

## Number of targets to track (1 = single target, >1 = multiple targets)
var target_count: int = 1

## List of currently valid targets in detection range
var valid_targets: Array[Node] = []

## Tracked best targets (size determined by target_count)
var tracked_targets: Array[Node] = []

## Whether to automatically remove invalid targets when getting best target
var auto_cleanup: bool = true

## Maximum number of targets to detect (0 = unlimited, applies to valid_targets)
var max_targets: int = 0

## Auto-refresh interval for AUTO update mode (in seconds)
var auto_refresh_interval: float = 0.5

## Whether to detect bodies (CharacterBody2D, RigidBody2D, etc.)
var detect_bodies: bool = true

## Whether to detect areas (Area2D)
var detect_areas: bool = true

## Custom filter/priority function for target validation and selection.[br]
## When priority = CUSTOM: func(targets: Array[Node]) -> Node (returns best target).[br]
## When priority != CUSTOM: func(target: Node) -> bool (validates if target is allowed).
var target_filter: Callable = Callable()

## Internal timer for AUTO update mode
var _refresh_timer: float = 0.0

## Emitted when a new target enters detection range and passes validation.[br]
## [param target]: The Node that entered detection.
signal target_found(target: Node)

## Emitted when a target leaves detection range or becomes invalid.[br]
## [param target]: The Node that left detection.
signal target_lost(target: Node)

## Emitted when tracked targets change (any update mode except MANUAL).[br]
## [param new_targets]: Array of currently tracked targets (size = target_count).
signal targets_changed(new_targets: Array[Node])

## Emitted when target list reaches max_targets limit.[br]
## [param rejected_target]: The target that couldn't be added.
signal target_limit_reached(rejected_target: Node)

## Constructor.[br]
## [param _owner]: The Object that owns this component (can be RefCounted).[br]
## [param _area]: Optional Area2D for detection (auto-detects if null).[br]
## [param _priority]: Initial targeting priority mode.
func _init(_owner: Object, _area: Area2D = null, _priority: Priority = Priority.CLOSEST) -> void:
	owner = _owner
	priority = _priority
	
	if _area:
		set_detection_area(_area)
	else:
		_auto_detect_area()


## Internal: Try to auto-detect Area2D from owner.
func _auto_detect_area() -> void:
	if not owner is Node:
		return
	
	var owner_node = owner as Node
	
	# Check if owner itself is Area2D
	if owner_node is Area2D:
		set_detection_area(owner_node)
		return
	
	# Check if owner has Area2D child
	for child in owner_node.get_children():
		if child is Area2D:
			set_detection_area(child)
			return
	
	# Check if owner's parent is Area2D
	var parent = owner_node.get_parent()
	if parent and parent is Area2D:
		set_detection_area(parent)


## Set or change the detection area.[br]
## Automatically disconnects from previous area and connects to new one.[br]
## [param area]: The Area2D to use for detection.
func set_detection_area(area: Area2D) -> void:
	# Disconnect from old area
	if detection_area and is_instance_valid(detection_area):
		if detect_bodies and detection_area.body_entered.is_connected(_on_body_entered):
			detection_area.body_entered.disconnect(_on_body_entered)
			detection_area.body_exited.disconnect(_on_body_exited)
		if detect_areas and detection_area.area_entered.is_connected(_on_area_entered):
			detection_area.area_entered.disconnect(_on_area_entered)
			detection_area.area_exited.disconnect(_on_area_exited)
	
	detection_area = area
	
	# Connect to new area
	if detection_area:
		if detect_bodies:
			detection_area.body_entered.connect(_on_body_entered)
			detection_area.body_exited.connect(_on_body_exited)
		if detect_areas:
			detection_area.area_entered.connect(_on_area_entered)
			detection_area.area_exited.connect(_on_area_exited)
		
		# Scan for existing targets in area
		_scan_existing_targets()


## Get the best target (single target mode).[br]
## [param force_recalculate]: Force recalculation regardless of update mode.[br]
## [return]: The best target Node, or null if no valid targets.
func get_best_target(force_recalculate: bool = false) -> Node:
	if update_mode == UpdateMode.MANUAL or force_recalculate:
		_recalculate_targets()
	
	return tracked_targets[0] if not tracked_targets.is_empty() else null


## Get multiple best targets (multi-target mode).[br]
## [param force_recalculate]: Force recalculation regardless of update mode.[br]
## [return]: Array of best targets (size up to target_count).
func get_best_targets(force_recalculate: bool = false) -> Array[Node]:
	if update_mode == UpdateMode.MANUAL or force_recalculate:
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
func get_all_targets() -> Array[Node]:
	return valid_targets.duplicate()


## Get number of valid targets in detection range.[br]
## [return]: Count of targets.
func get_target_count() -> int:
	return valid_targets.size()


## Get number of currently tracked targets.[br]
## [return]: Count of tracked targets (up to target_count limit).
func get_tracked_count() -> int:
	return tracked_targets.size()


## Check if a specific node is currently in detection range.[br]
## [param target]: The Node to check.[br]
## [return]: true if target is in valid_targets list.
func has_target(target: Node) -> bool:
	return valid_targets.has(target)


## Check if a specific node is currently being tracked.[br]
## [param target]: The Node to check.[br]
## [return]: true if target is in tracked_targets list.
func is_tracking(target: Node) -> bool:
	return tracked_targets.has(target)


## Manually add a target (bypasses area detection).[br]
## [param target]: The Node to add as a target.[br]
## [return]: true if successfully added.
func add_target(target: Node) -> bool:
	if not is_instance_valid(target) or valid_targets.has(target):
		return false
	
	# Check custom filter (only for non-CUSTOM priority)
	if priority != Priority.CUSTOM and target_filter.is_valid():
		if not target_filter.call(target):
			return false
	
	# Check max targets limit
	if max_targets > 0 and valid_targets.size() >= max_targets:
		target_limit_reached.emit(target)
		return false
	
	valid_targets.append(target)
	target_found.emit(target)
	
	# Trigger update based on mode
	if update_mode == UpdateMode.ON_ENTER or _should_update_on_entry():
		_recalculate_targets()
	
	return true


## Manually remove a target.[br]
## [param target]: The Node to remove from targets.[br]
## [return]: true if target was removed.
func remove_target(target: Node) -> bool:
	if valid_targets.has(target):
		valid_targets.erase(target)
		target_lost.emit(target)
		
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
## For Priority.CUSTOM: func(targets: Array[Node]) -> Node (select best).[br]
## For other priorities: func(target: Node) -> bool (validate target).[br]
## [param filter_func]: Callable with appropriate signature.[br]
## [param revalidate_existing]: Whether to revalidate existing targets.
func set_target_filter(filter_func: Callable, revalidate_existing: bool = false) -> void:
	target_filter = filter_func
	
	if revalidate_existing and target_filter.is_valid() and priority != Priority.CUSTOM:
		var to_remove: Array[Node] = []
		for target in valid_targets:
			if not target_filter.call(target):
				to_remove.append(target)
		
		for target in to_remove:
			remove_target(target)


## Clear the custom target filter.
func clear_target_filter() -> void:
	target_filter = Callable()


## Change targeting priority mode.[br]
## [param new_priority]: New Priority enum value.
func set_priority(new_priority: Priority) -> void:
	if priority != new_priority:
		priority = new_priority


## Change update mode.[br]
## [param new_mode]: New UpdateMode enum value.
func set_update_mode(new_mode: UpdateMode) -> void:
	update_mode = new_mode
	_refresh_timer = 0.0


## Change target count (switches between single/multi-target mode).[br]
## [param count]: Number of targets to track (1 = single, >1 = multiple).
func set_target_count(count: int) -> void:
	target_count = maxi(1, count)


## Internal: Check if should update when target enters (for ON_TARGET_LOST mode).
func _should_update_on_entry() -> bool:
	# In ON_TARGET_LOST mode, update if we have fewer tracked targets than target_count
	return update_mode == UpdateMode.ON_TARGET_LOST and tracked_targets.size() < target_count


## Internal: Check if should update when target lost (for ON_TARGET_LOST mode).
func _should_update_on_loss(target: Node) -> bool:
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
	
	var new_tracked: Array[Node] = []
	
	# Single target optimization
	if target_count == 1:
		var best = _get_single_best_target()
		if best:
			new_tracked.append(best)
	else:
		# Multiple targets
		new_tracked = _get_multiple_best_targets()
	
	# Check if targets actually changed
	if _targets_differ(tracked_targets, new_tracked):
		tracked_targets = new_tracked
		targets_changed.emit(tracked_targets)


## Internal: Check if two target arrays differ.
func _targets_differ(old: Array[Node], new: Array[Node]) -> bool:
	if old.size() != new.size():
		return true
	
	for i in range(old.size()):
		if old[i] != new[i]:
			return true
	
	return false


## Internal: Get single best target based on priority.
func _get_single_best_target() -> Node:
	match priority:
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
			else:
				push_warning("TargetingComponent: CUSTOM priority requires target_filter to be set")
				return valid_targets[0] if not valid_targets.is_empty() else null
	
	return null


## Internal: Get multiple best targets based on priority.
func _get_multiple_best_targets() -> Array[Node]:
	var sorted_targets: Array[Node] = valid_targets.duplicate()
	
	# Sort based on priority
	match priority:
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
				if custom_result is Array:
					sorted_targets = custom_result
	
	# Return up to target_count targets
	if sorted_targets.size() > target_count:
		sorted_targets.resize(target_count)
	
	return sorted_targets


## Internal: Handle body entering detection area.
func _on_body_entered(body: Node) -> void:
	_handle_target_entered(body)


## Internal: Handle area entering detection area.
func _on_area_entered(area: Node) -> void:
	_handle_target_entered(area)


## Internal: Handle body exiting detection area.
func _on_body_exited(body: Node) -> void:
	_handle_target_exited(body)


## Internal: Handle area exiting detection area.
func _on_area_exited(area: Node) -> void:
	_handle_target_exited(area)


## Internal: Common logic for target entering.
func _handle_target_entered(target: Node) -> void:
	# Avoid duplicates
	if valid_targets.has(target):
		return
	
	# Check custom filter (only for non-CUSTOM priority)
	if priority != Priority.CUSTOM and target_filter.is_valid():
		if not target_filter.call(target):
			return
	
	# Check max targets limit
	if max_targets > 0 and valid_targets.size() >= max_targets:
		target_limit_reached.emit(target)
		return
	
	valid_targets.append(target)
	target_found.emit(target)
	
	# Trigger update based on mode
	if update_mode == UpdateMode.ON_ENTER or _should_update_on_entry():
		_recalculate_targets()


## Internal: Common logic for target exiting.
func _handle_target_exited(target: Node) -> void:
	if valid_targets.has(target):
		valid_targets.erase(target)
		target_lost.emit(target)
		
		# Trigger update based on mode
		if update_mode == UpdateMode.ON_EXIT or _should_update_on_loss(target):
			_recalculate_targets()


## Internal: Scan for targets already in detection area (called when area changes).
func _scan_existing_targets() -> void:
	if not detection_area:
		return
	
	if detect_bodies:
		var bodies = detection_area.get_overlapping_bodies()
		for body in bodies:
			_handle_target_entered(body)
	
	if detect_areas:
		var areas = detection_area.get_overlapping_areas()
		for area in areas:
			_handle_target_entered(area)


## Internal: Find closest target by distance.
func _get_closest_target() -> Node:
	if not owner is Node2D:
		return valid_targets[0] if not valid_targets.is_empty() else null
	
	var owner_node = owner as Node2D  # Changed to Node2D
	var closest: Node = null
	var min_dist = INF
	
	for target in valid_targets:
		if not is_instance_valid(target) or not target is Node2D:
			continue
		
		var target_node = target as Node2D
		var dist = owner_node.global_position.distance_squared_to(target_node.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = target_node
	
	return closest

## Internal: Find farthest target by distance.
func _get_farthest_target() -> Node2D:
	if not owner is Node2D:
		return valid_targets[-1] if not valid_targets.is_empty() else null
	
	var owner_node = owner as Node2D
	var farthest: Node2D = null
	var max_dist = -INF
	
	for target in valid_targets:
		if not is_instance_valid(target):
			continue
		
		var dist = owner_node.global_position.distance_squared_to(target.global_position)
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
func _sort_by_distance(targets: Array[Node], ascending: bool) -> Array[Node]:
	if not owner is Node:
		return targets
	
	var owner_node = owner as Node
	targets.sort_custom(func(a, b):
		var dist_a = owner_node.global_position.distance_squared_to(a.global_position)
		var dist_b = owner_node.global_position.distance_squared_to(b.global_position)
		return dist_a < dist_b if ascending else dist_a > dist_b
	)
	return targets


## Internal: Sort targets by health.
func _sort_by_health(targets: Array[Node], ascending: bool) -> Array[Node]:
	var filtered_targets: Array[Node] = []
	
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
func _get_target_health(target: Node) -> float:
	# Try get_health() method first
	if target.has_method("get_health"):
		return target.get_health()
	
	# Try health property
	if "health" in target:
		var health_prop = target.get("health")
		if health_prop is float or health_prop is int:
			return float(health_prop)
		elif health_prop is Stat:
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
