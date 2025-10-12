class_name CollectionComponent
extends RefCounted

## Automatic pickup/collection component for Area2D-based detection.[br]
##[br]
## This component detects and collects items (coins, XP orbs, powerups, etc.)[br]
## using an Area2D. Supports automatic collection, manual collection with filters,[br]
## magnetic attraction, and various collection modes. Similar to TargetingComponent[br]
## but specialized for collectible items rather than combat targets.

## Collection mode determines how items are collected
enum CollectionMode {
	AUTOMATIC,     ## Auto-collect on contact
	MANUAL,        ## Require manual collect() call
	ON_INPUT,      ## Collect when input action pressed
	MAGNETIC       ## Items are attracted then collected
}

## Shape types for collection range
enum ShapeType {
	CIRCLE,
	RECTANGLE,
	CAPSULE,
	CUSTOM
}

## Reference to the entity that owns this component
var owner: Object = null

## Area2D used for item detection
var detection_area: Area2D = null

## Current collection mode
var collection_mode: CollectionMode = CollectionMode.AUTOMATIC

## List of collectible items in range
var items_in_range: Array[Node] = []

## Whether to automatically remove invalid items
var auto_cleanup: bool = true

## Maximum items that can be collected per frame (0 = unlimited)
var max_per_frame: int = 0

## Collection filter function: func(item: Node) -> bool
var collection_filter: Callable = Callable()

## Input action for ON_INPUT mode
var input_action: String = "interact"

## Whether to detect bodies (RigidBody2D, CharacterBody2D, etc.)
var detect_bodies: bool = true

## Whether to detect areas (Area2D)
var detect_areas: bool = true

## Maximum number of items in range (0 = unlimited)
var max_items_in_range: int = 0

## Magnetic attraction settings
var magnetic_enabled: bool = false
var magnetic_strength: float = 200.0
var magnetic_max_speed: float = 300.0
var magnetic_acceleration: float = 500.0

## Collection range and shape management
var detection_range: float = 50.0:
	set(value):
		var old_range = detection_range
		detection_range = value
		if auto_update_shape:
			_update_collision_shape(detection_range)
		range_changed.emit(detection_range * range_multiplier, old_range * range_multiplier)

var collision_shape: CollisionShape2D = null
var range_multiplier: float = 1.0
var auto_update_shape: bool = true
var shape_type: ShapeType = ShapeType.CUSTOM

## Emitted when an item is collected.[br]
## [param item]: The Node that was collected.[br]
## [param item_type]: String type identifier if item has "item_type" property.
signal item_collected(item: Node, item_type: String)

## Emitted when an item enters collection range.[br]
## [param item]: The Node that entered range.
signal item_detected(item: Node)

## Emitted when an item leaves collection range.[br]
## [param item]: The Node that left range.
signal item_lost(item: Node)

## Emitted when collection attempt fails (invalid item, filter rejected, etc.).[br]
## [param item]: The Node that failed to be collected.
signal collection_failed(item: Node)

## Emitted when items_in_range reaches max limit.[br]
## [param rejected_item]: The item that couldn't be added.
signal item_limit_reached(rejected_item: Node)

## Emitted when range changes
signal range_changed(new_range: float, old_range: float)


func _init(_owner: Object, _area: Area2D = null, _mode: CollectionMode = CollectionMode.AUTOMATIC) -> void:
	owner = _owner
	collection_mode = _mode
	
	if _area:
		set_detection_area(_area)
	else:
		_auto_detect_area()


## Internal: Try to auto-detect Area2D from owner
func _auto_detect_area() -> void:
	if not owner is Node:
		return
	
	var owner_node = owner as Node
	
	# Check if owner is Area2D
	if owner_node is Area2D:
		set_detection_area(owner_node)
		return
	
	# Check children
	for child in owner_node.get_children():
		if child is Area2D:
			set_detection_area(child)
			return
	
	# Check parent
	var parent = owner_node.get_parent()
	if parent and parent is Area2D:
		set_detection_area(parent)


## Set or change the detection area.[br]
## [param area]: The Area2D to use for detection.
func set_detection_area(area: Area2D) -> void:
	# Disconnect old area
	if detection_area and is_instance_valid(detection_area):
		if detect_bodies and detection_area.body_entered.is_connected(_on_body_entered):
			detection_area.body_entered.disconnect(_on_body_entered)
			detection_area.body_exited.disconnect(_on_body_exited)
		if detect_areas and detection_area.area_entered.is_connected(_on_area_entered):
			detection_area.area_entered.disconnect(_on_area_entered)
			detection_area.area_exited.disconnect(_on_area_exited)
	
	detection_area = area
	
	# Connect new area
	if detection_area:
		if detect_bodies:
			detection_area.body_entered.connect(_on_body_entered)
			detection_area.body_exited.connect(_on_body_exited)
		if detect_areas:
			detection_area.area_entered.connect(_on_area_entered)
			detection_area.area_exited.connect(_on_area_exited)
		
		_scan_existing_items()
	
	_detect_collision_shape()


## Update component (call in _process or _physics_process).[br]
## [param delta]: Time elapsed since last frame.
func update(delta: float) -> void:
	if auto_cleanup:
		_cleanup_invalid_items()
	
	# Handle magnetic attraction
	if magnetic_enabled and collection_mode == CollectionMode.MAGNETIC:
		_update_magnetic_attraction(delta)
	
	# Handle input-based collection
	if collection_mode == CollectionMode.ON_INPUT:
		if Input.is_action_just_pressed(input_action):
			collect_all()


## Manually collect a specific item.[br>
## [param item]: The Node to collect.[br]
## [return]: true if successfully collected.
func collect_item(item: Node) -> bool:
	if not is_instance_valid(item):
		return false
	
	# Check if in range
	if not items_in_range.has(item):
		return false
	
	# Apply filter
	if collection_filter.is_valid():
		if not collection_filter.call(item):
			collection_failed.emit(item)
			return false
	
	# Get item type
	var item_type = _get_item_type(item)
	
	# Remove from tracking
	items_in_range.erase(item)
	
	# Emit signal before destroying item
	item_collected.emit(item, item_type)
	
	# Destroy/hide item
	_destroy_item(item)
	
	return true


## Collect all items currently in range.[br]
## [param respect_max_per_frame]: Whether to honor max_per_frame limit.[br]
## [return]: Number of items collected.
func collect_all(respect_max_per_frame: bool = true) -> int:
	var collected = 0
	var limit = max_per_frame if respect_max_per_frame and max_per_frame > 0 else items_in_range.size()
	
	# Collect up to limit
	var i = items_in_range.size() - 1
	while i >= 0 and collected < limit:
		var item = items_in_range[i]
		if collect_item(item):
			collected += 1
		i -= 1
	
	return collected


## Collect closest item in range.[br]
## [return]: The collected item, or null if none available.
func collect_closest() -> Node:
	if items_in_range.is_empty():
		return null
	
	var closest = _get_closest_item()
	if closest and collect_item(closest):
		return closest
	
	return null


## Get all items currently in collection range.[br]
## [return]: Array of item Nodes.
func get_items_in_range() -> Array[Node]:
	return items_in_range.duplicate()


## Get count of items in range.[br]
## [return]: Number of items.
func get_item_count() -> int:
	return items_in_range.size()


## Check if a specific item is in range.[br]
## [param item]: The Node to check.[br]
## [return]: true if item is in items_in_range.
func has_item(item: Node) -> bool:
	return items_in_range.has(item)


## Set collection filter function.[br]
## [param filter_func]: Callable with signature func(item: Node) -> bool.[br]
## [param revalidate_existing]: Whether to remove existing items that fail filter.
func set_collection_filter(filter_func: Callable, revalidate_existing: bool = false) -> void:
	collection_filter = filter_func
	
	if revalidate_existing and collection_filter.is_valid():
		var to_remove: Array[Node] = []
		for item in items_in_range:
			if not collection_filter.call(item):
				to_remove.append(item)
		
		for item in to_remove:
			items_in_range.erase(item)
			item_lost.emit(item)


## Clear the collection filter.
func clear_collection_filter() -> void:
	collection_filter = Callable()


## Set collection mode.[br]
## [param mode]: New CollectionMode value.
func set_collection_mode(mode: CollectionMode) -> void:
	collection_mode = mode


## Enable/disable magnetic attraction.[br]
## [param enabled]: Whether magnetic collection is active.
func set_magnetic_enabled(enabled: bool) -> void:
	magnetic_enabled = enabled


## Set magnetic strength (acceleration toward collector).[br]
## [param strength]: Attraction strength in pixels/second^2.
func set_magnetic_strength(strength: float) -> void:
	magnetic_strength = strength


## Clear all items from tracking.[br]
## [param emit_signals]: Whether to emit item_lost for each item.
func clear_items(emit_signals: bool = false) -> void:
	if emit_signals:
		for item in items_in_range:
			item_lost.emit(item)
	
	items_in_range.clear()


## Internal: Handle body entering detection
func _on_body_entered(body: Node) -> void:
	_handle_item_entered(body)


## Internal: Handle area entering detection
func _on_area_entered(area: Node) -> void:
	_handle_item_entered(area)


## Internal: Handle body exiting detection
func _on_body_exited(body: Node) -> void:
	_handle_item_exited(body)


## Internal: Handle area exiting detection
func _on_area_exited(area: Node) -> void:
	_handle_item_exited(area)


## Internal: Common logic for item entering range
func _handle_item_entered(item: Node) -> void:
	# Avoid duplicates
	if items_in_range.has(item):
		return
	
	# Apply filter
	if collection_filter.is_valid():
		if not collection_filter.call(item):
			return
	
	# Check max items limit
	if max_items_in_range > 0 and items_in_range.size() >= max_items_in_range:
		item_limit_reached.emit(item)
		return
	
	items_in_range.append(item)
	item_detected.emit(item)
	
	# Auto-collect if in automatic mode
	if collection_mode == CollectionMode.AUTOMATIC:
		collect_item(item)


## Internal: Common logic for item exiting range
func _handle_item_exited(item: Node) -> void:
	if items_in_range.has(item):
		items_in_range.erase(item)
		item_lost.emit(item)


## Internal: Scan for items already in area
func _scan_existing_items() -> void:
	if not detection_area:
		return
	
	if detect_bodies:
		var bodies = detection_area.get_overlapping_bodies()
		for body in bodies:
			_handle_item_entered(body)
	
	if detect_areas:
		var areas = detection_area.get_overlapping_areas()
		for area in areas:
			_handle_item_entered(area)


## Internal: Update magnetic attraction for all items
func _update_magnetic_attraction(delta: float) -> void:
	if not owner is Node2D:
		return
	
	var owner_pos = (owner as Node2D).global_position
	
	for item in items_in_range:
		if not is_instance_valid(item) or not item is Node2D:
			continue
		
		var item_node = item as Node2D
		var direction = (owner_pos - item_node.global_position).normalized()
		var distance = owner_pos.distance_to(item_node.global_position)
		
		# Calculate attraction force (stronger when closer)
		var force_multiplier = 1.0 + (1.0 - clampf(distance / get_range(), 0.0, 1.0))
		var velocity = direction * magnetic_strength * force_multiplier * delta
		
		# Apply velocity (check if item has position property)
		if "global_position" in item_node:
			item_node.global_position += velocity.limit_length(magnetic_max_speed * delta)
		
		# Auto-collect when very close
		if distance < 10.0:
			collect_item(item)


## Internal: Get closest item by distance
func _get_closest_item() -> Node:
	if not owner is Node2D:
		return items_in_range[0] if not items_in_range.is_empty() else null
	
	var owner_node = owner as Node2D
	var closest: Node = null
	var min_dist = INF
	
	for item in items_in_range:
		if not is_instance_valid(item) or not item is Node2D:
			continue
		
		var item_node = item as Node2D
		var dist = owner_node.global_position.distance_squared_to(item_node.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = item
	
	return closest


## Internal: Get item type identifier
func _get_item_type(item: Node) -> String:
	if "item_type" in item:
		return item.get("item_type")
	elif "type" in item:
		return item.get("type")
	else:
		return item.name


## Internal: Destroy or hide collected item
func _destroy_item(item: Node) -> void:
	if not is_instance_valid(item):
		return
	
	# Check if item has custom collection behavior
	if item.has_method("on_collected"):
		item.call("on_collected")
		return
	
	# Default: queue_free the item
	if item.has_method("queue_free"):
		item.queue_free()


## Internal: Remove invalid items from list
func _cleanup_invalid_items() -> int:
	var removed = 0
	var i = items_in_range.size() - 1
	
	while i >= 0:
		var item = items_in_range[i]
		if not is_instance_valid(item):
			items_in_range.remove_at(i)
			item_lost.emit(item)
			removed += 1
		i -= 1
	
	return removed


## Detect and configure collision shape
func _detect_collision_shape() -> void:
	if not detection_area:
		return
	
	for child in detection_area.get_children():
		if child is CollisionShape2D:
			collision_shape = child
			break
	
	if not collision_shape:
		push_warning("CollectionComponent: No CollisionShape2D found")
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
	
	if auto_update_shape:
		_update_collision_shape(detection_range)


## Update collision shape size
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


## Get current effective range
func get_range() -> float:
	return detection_range * range_multiplier


## Set range multiplier
func set_range_multiplier(multiplier: float, update_shape: bool = true) -> void:
	range_multiplier = multiplier
	
	if update_shape and auto_update_shape:
		_update_collision_shape(detection_range)
