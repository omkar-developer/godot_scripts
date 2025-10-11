class_name TargetingComponent
extends RefCounted

## Target selection and tracking component for Area2D-based detection.[br]
##[br]
## This component manages target detection through an Area2D and provides various[br]
## targeting priorities (closest, lowest HP, random, etc.). It automatically tracks[br]
## valid targets and cleans up invalid ones. Works with any Node that enters the[br]
## detection area - filtering can be done via collision layers or custom validation.

## Target priority modes
enum Priority {
	CLOSEST,      ## Target nearest enemy by distance
	FARTHEST,     ## Target farthest enemy
	LOWEST_HP,    ## Target enemy with lowest health (requires get_health method)
	HIGHEST_HP,   ## Target enemy with highest health (requires get_health method)
	RANDOM,       ## Pick random target from valid list
	FIRST_SEEN,   ## Target first enemy that entered detection
	LAST_SEEN     ## Target most recent enemy that entered detection
}

## Reference to the entity that owns this component
var owner: Node = null

## Area2D used for target detection (connect body_entered/exited signals)
var detection_area: Area2D = null

## Current targeting priority mode
var priority: Priority = Priority.CLOSEST

## List of currently valid targets in detection range
var valid_targets: Array[Node] = []

## Whether to automatically remove invalid targets each frame (performance cost)
var auto_cleanup: bool = true

## Maximum number of targets to track (0 = unlimited)
var max_targets: int = 0

## Custom filter function for target validation (optional)
## Signature: func(target: Node) -> bool
var target_filter: Callable = Callable()

## Emitted when a new target enters detection range and passes validation.[br]
## [param target]: The Node that entered detection.
signal target_found(target: Node)

## Emitted when a target leaves detection range or becomes invalid.[br]
## [param target]: The Node that left detection.
signal target_lost(target: Node)

## Emitted when the best target changes.[br]
## [param new_target]: The new best target (or null if none).[br]
## [param old_target]: The previous best target (or null if none).
signal target_changed(new_target: Node, old_target: Node)

## Emitted when target list reaches max_targets limit.[br]
## [param rejected_target]: The target that couldn't be added.
signal target_limit_reached(rejected_target: Node)

## Constructor.[br]
## [param _owner]: The Node that owns this component.[br]
## [param _area]: Optional Area2D for detection (can be set later).[br]
## [param _priority]: Initial targeting priority mode.
func _init(_owner: Node, _area: Area2D = null, _priority: Priority = Priority.CLOSEST) -> void:
	owner = _owner
	priority = _priority
	
	if _area:
		set_detection_area(_area)


## Set or change the detection area.[br]
## Automatically disconnects from previous area and connects to new one.[br]
## [param area]: The Area2D to use for detection.
func set_detection_area(area: Area2D) -> void:
	# Disconnect from old area
	if detection_area and is_instance_valid(detection_area):
		if detection_area.body_entered.is_connected(_on_body_entered):
			detection_area.body_entered.disconnect(_on_body_entered)
			detection_area.body_exited.disconnect(_on_body_exited)
	
	detection_area = area
	
	# Connect to new area
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)
		
		# Scan for existing bodies in area
		_scan_existing_targets()


## Get the best target based on current priority mode.[br]
## [return]: The best target Node, or null if no valid targets.
func get_best_target() -> Node:
	if valid_targets.is_empty():
		return null
	
	# Clean invalid targets if auto-cleanup enabled
	if auto_cleanup:
		_cleanup_invalid_targets()
	
	if valid_targets.is_empty():
		return null
	
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
	
	return null


## Get all currently valid targets.[br]
## [return]: Array of valid target Nodes (copy of internal list).
func get_all_targets() -> Array[Node]:
	return valid_targets.duplicate()


## Get number of valid targets.[br]
## [return]: Count of targets in detection range.
func get_target_count() -> int:
	return valid_targets.size()


## Check if a specific node is currently targeted.[br]
## [param target]: The Node to check.[br]
## [return]: true if target is in valid_targets list.
func has_target(target: Node) -> bool:
	return valid_targets.has(target)


## Manually add a target (bypasses area detection).[br]
## [param target]: The Node to add as a target.[br]
## [return]: true if successfully added.
func add_target(target: Node) -> bool:
	if not is_instance_valid(target) or valid_targets.has(target):
		return false
	
	# Check custom filter
	if target_filter.is_valid() and not target_filter.call(target):
		return false
	
	# Check max targets limit
	if max_targets > 0 and valid_targets.size() >= max_targets:
		target_limit_reached.emit(target)
		return false
	
	valid_targets.append(target)
	target_found.emit(target)
	return true


## Manually remove a target.[br]
## [param target]: The Node to remove from targets.[br]
## [return]: true if target was removed.
func remove_target(target: Node) -> bool:
	if valid_targets.has(target):
		valid_targets.erase(target)
		target_lost.emit(target)
		return true
	return false


## Clear all targets.[br]
## [param emit_signals]: Whether to emit target_lost for each target.
func clear_targets(emit_signals: bool = false) -> void:
	if emit_signals:
		for target in valid_targets:
			target_lost.emit(target)
	
	valid_targets.clear()


## Remove invalid/freed targets from list.[br]
## Called automatically if auto_cleanup is true.[br]
## [return]: Number of targets removed.
func clear_invalid_targets() -> int:
	return _cleanup_invalid_targets()


## Set custom target filter function.[br]
## [param filter_func]: Callable with signature func(target: Node) -> bool.[br]
## [param revalidate_existing]: Whether to revalidate existing targets.
func set_target_filter(filter_func: Callable, revalidate_existing: bool = false) -> void:
	target_filter = filter_func
	
	if revalidate_existing and target_filter.is_valid():
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
	priority = new_priority


## Internal: Handle body entering detection area.
func _on_body_entered(body: Node) -> void:
	# Avoid duplicates
	if valid_targets.has(body):
		return
	
	# Check custom filter
	if target_filter.is_valid() and not target_filter.call(body):
		return
	
	# Check max targets limit
	if max_targets > 0 and valid_targets.size() >= max_targets:
		target_limit_reached.emit(body)
		return
	
	valid_targets.append(body)
	target_found.emit(body)


## Internal: Handle body exiting detection area.
func _on_body_exited(body: Node) -> void:
	if valid_targets.has(body):
		valid_targets.erase(body)
		target_lost.emit(body)


## Internal: Scan for bodies already in detection area (called when area changes).
func _scan_existing_targets() -> void:
	if not detection_area:
		return
	
	var bodies := detection_area.get_overlapping_bodies()
	for body in bodies:
		_on_body_entered(body)


## Internal: Find closest target by distance.
func _get_closest_target() -> Node:
	if not owner:
		return valid_targets[0] if not valid_targets.is_empty() else null
	
	var closest: Node = null
	var min_dist := INF
	
	for target in valid_targets:
		if not is_instance_valid(target):
			continue
		
		var dist = owner.global_position.distance_squared_to(target.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = target
	
	return closest


## Internal: Find farthest target by distance.
func _get_farthest_target() -> Node:
	if not owner:
		return valid_targets[-1] if not valid_targets.is_empty() else null
	
	var farthest: Node = null
	var max_dist := -INF
	
	for target in valid_targets:
		if not is_instance_valid(target):
			continue
		
		var dist = owner.global_position.distance_squared_to(target.global_position)
		if dist > max_dist:
			max_dist = dist
			farthest = target
	
	return farthest


## Internal: Find target with lowest HP.
func _get_lowest_hp_target() -> Node:
	var lowest: Node = null
	var min_hp := INF
	
	for target in valid_targets:
		if not is_instance_valid(target):
			continue
		
		var hp := _get_target_health(target)
		if hp < 0.0:  # Target has no health method
			continue
		
		if hp < min_hp:
			min_hp = hp
			lowest = target
	
	return lowest


## Internal: Find target with highest HP.
func _get_highest_hp_target() -> Node:
	var highest: Node = null
	var max_hp := -INF
	
	for target in valid_targets:
		if not is_instance_valid(target):
			continue
		
		var hp := _get_target_health(target)
		if hp < 0.0:  # Target has no health method
			continue
		
		if hp > max_hp:
			max_hp = hp
			highest = target
	
	return highest


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
	var removed := 0
	var i := valid_targets.size() - 1
	
	while i >= 0:
		var target := valid_targets[i]
		if not is_instance_valid(target):
			valid_targets.remove_at(i)
			target_lost.emit(target)
			removed += 1
		i -= 1
	
	return removed
