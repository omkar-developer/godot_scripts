class_name CollectionComponent
extends RefCounted

## Two-area collection system: detection range + collection trigger.[br]
##[br]
## Uses two separate Area2D nodes:[br]
## - Detection Area: Large area for detecting items, magnetic pull, filtering[br]
## - Collection Area: Small area (e.g. ship collision) for actual pickup[br]
## This allows ship collision to remain small while collection range is large.

## Collection mode determines behavior
enum CollectionMode {
	AUTOMATIC,     ## Auto-collect when items enter collection_area
	MANUAL,        ## Require manual collect() call
	ON_INPUT,      ## Collect when input action pressed
	MAGNETIC       ## Items pulled to player, collected on collection_area contact
}

## Shape types for range detection
enum ShapeType {
	CIRCLE,
	RECTANGLE,
	CAPSULE,
	CUSTOM
}

## Reference to the entity that owns this component
var owner: Object = null

## Large area for item DETECTION and magnetic pull
var detection_area: Area2D = null

## Small area for actual COLLECTION (e.g. ship collision area)
var collection_area: Area2D = null

## Current collection mode
var collection_mode: CollectionMode = CollectionMode.MAGNETIC

## Items detected in range (can be pulled)
var detected_items: Array[Node] = []

## Items in collection range (ready to collect)
var collectible_items: Array[Node] = []

## Whether to automatically remove invalid items
var auto_cleanup: bool = true

## Maximum items collected per frame (0 = unlimited)
var max_per_frame: int = 0

## Collection filter function: func(item: Node) -> bool
var collection_filter: Callable = Callable()

## Input action for ON_INPUT mode
var input_action: String = "interact"

## Whether to detect bodies in detection area
var detect_bodies: bool = true

## Whether to detect areas in detection area
var detect_areas: bool = true

## Maximum items in detection range (0 = unlimited)
var max_detected_items: int = 0

## Magnetic attraction settings
var magnetic_enabled: bool = true
var magnetic_strength: float = 300.0
var magnetic_max_speed: float = 400.0
var magnetic_min_distance: float = 5.0  # Stop pulling when this close

## Detection range management
var detection_range: float = 150.0:
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

## Emitted when an item is collected
signal item_collected(item: Node, item_type: String)

## Emitted when an item enters detection range
signal item_detected(item: Node)

## Emitted when an item leaves detection range
signal item_lost(item: Node)

## Emitted when an item enters collection range
signal item_ready_to_collect(item: Node)

## Emitted when collection fails
signal collection_failed(item: Node)

## Emitted when detection limit reached
signal detection_limit_reached(rejected_item: Node)

## Emitted when range changes
signal range_changed(new_range: float, old_range: float)


func _init(
	_owner: Object,
	_detection_area: Area2D = null,
	_collection_area: Area2D = null,
	_mode: CollectionMode = CollectionMode.MAGNETIC
) -> void:
	owner = _owner
	collection_mode = _mode
	
	if _detection_area:
		set_detection_area(_detection_area)
	
	if _collection_area:
		set_collection_area(_collection_area)
	elif _detection_area:
		# Default: use detection area as collection area too
		set_collection_area(_detection_area)


## Set the detection area (large range for item detection).[br]
## [param area]: Area2D for detecting items at distance.
func set_detection_area(area: Area2D) -> void:
	# Disconnect old area
	if detection_area and is_instance_valid(detection_area):
		if detect_bodies and detection_area.body_entered.is_connected(_on_detection_body_entered):
			detection_area.body_entered.disconnect(_on_detection_body_entered)
			detection_area.body_exited.disconnect(_on_detection_body_exited)
		if detect_areas and detection_area.area_entered.is_connected(_on_detection_area_entered):
			detection_area.area_entered.disconnect(_on_detection_area_entered)
			detection_area.area_exited.disconnect(_on_detection_area_exited)
	
	detection_area = area
	
	# Connect new area
	if detection_area:
		if detect_bodies:
			detection_area.body_entered.connect(_on_detection_body_entered)
			detection_area.body_exited.connect(_on_detection_body_exited)
		if detect_areas:
			detection_area.area_entered.connect(_on_detection_area_entered)
			detection_area.area_exited.connect(_on_detection_area_exited)
		
		_scan_existing_detected()
	
	_detect_collision_shape()


## Set the collection area (small trigger for actual pickup).[br]
## [param area]: Area2D that triggers collection (e.g. ship collision).
func set_collection_area(area: Area2D) -> void:
	# Disconnect old area
	if collection_area and is_instance_valid(collection_area):
		if collection_area.body_entered.is_connected(_on_collection_body_entered):
			collection_area.body_entered.disconnect(_on_collection_body_entered)
			collection_area.body_exited.disconnect(_on_collection_body_exited)
		if collection_area.area_entered.is_connected(_on_collection_area_entered):
			collection_area.area_entered.disconnect(_on_collection_area_entered)
			collection_area.area_exited.disconnect(_on_collection_area_exited)
	
	collection_area = area
	
	# Connect new area
	if collection_area:
		collection_area.body_entered.connect(_on_collection_body_entered)
		collection_area.body_exited.connect(_on_collection_body_exited)
		collection_area.area_entered.connect(_on_collection_area_entered)
		collection_area.area_exited.connect(_on_collection_area_exited)
		
		_scan_existing_collectible()


## Update component (call in _process or _physics_process).[br]
## [param delta]: Time elapsed since last frame.
func update(delta: float) -> void:
	if auto_cleanup:
		_cleanup_invalid_items()
	
	# Handle magnetic attraction
	if magnetic_enabled:
		_update_magnetic_attraction(delta)
	
	# Handle input-based collection
	if collection_mode == CollectionMode.ON_INPUT:
		if Input.is_action_just_pressed(input_action):
			collect_all()


## Manually collect a specific item.[br]
## [param item]: The Node to collect.[br]
## [return]: true if successfully collected.
func collect_item(item: Node) -> bool:
	if not is_instance_valid(item):
		return false
	
	# Check if in collectible range (or allow from detected if manual mode)
	var in_range = collectible_items.has(item)
	if not in_range and collection_mode != CollectionMode.MANUAL:
		return false
	
	if collection_mode == CollectionMode.MANUAL and not detected_items.has(item):
		return false
	
	# Apply filter
	if collection_filter.is_valid():
		if not collection_filter.call(item):
			collection_failed.emit(item)
			return false
	
	# Get item type
	var item_type = _get_item_type(item)
	
	# Remove from tracking
	detected_items.erase(item)
	collectible_items.erase(item)
	
	# Emit signal before destroying item
	item_collected.emit(item, item_type)
	
	# Destroy/hide item
	_destroy_item(item)
	
	return true


## Collect all items in collection range.[br]
## [param respect_max_per_frame]: Whether to honor max_per_frame limit.[br]
## [return]: Number of items collected.
func collect_all(respect_max_per_frame: bool = true) -> int:
	var collected = 0
	var limit = max_per_frame if respect_max_per_frame and max_per_frame > 0 else collectible_items.size()
	
	var i = collectible_items.size() - 1
	while i >= 0 and collected < limit:
		var item = collectible_items[i]
		if collect_item(item):
			collected += 1
		i -= 1
	
	return collected


## Collect closest item in detection range.[br]
## [return]: The collected item, or null if none available.
func collect_closest() -> Node:
	if detected_items.is_empty():
		return null
	
	var closest = _get_closest_item()
	if closest and collect_item(closest):
		return closest
	
	return null


## Get all detected items.[br]
## [return]: Array of detected item Nodes.
func get_detected_items() -> Array[Node]:
	return detected_items.duplicate()


## Get all collectible items (in collection range).[br]
## [return]: Array of collectible item Nodes.
func get_collectible_items() -> Array[Node]:
	return collectible_items.duplicate()


## Get count of detected items.[br]
## [return]: Number of items in detection range.
func get_detected_count() -> int:
	return detected_items.size()


## Get count of collectible items.[br]
## [return]: Number of items in collection range.
func get_collectible_count() -> int:
	return collectible_items.size()


## Check if item is detected.[br]
## [param item]: The Node to check.[br]
## [return]: true if in detection range.
func has_detected(item: Node) -> bool:
	return detected_items.has(item)


## Check if item is collectible.[br]
## [param item]: The Node to check.[br]
## [return]: true if in collection range.
func has_collectible(item: Node) -> bool:
	return collectible_items.has(item)


## Set collection filter function.[br]
## [param filter_func]: Callable with signature func(item: Node) -> bool.
func set_collection_filter(filter_func: Callable) -> void:
	collection_filter = filter_func


## Clear the collection filter.
func clear_collection_filter() -> void:
	collection_filter = Callable()


## Set collection mode.[br]
## [param mode]: New CollectionMode value.
func set_collection_mode(mode: CollectionMode) -> void:
	collection_mode = mode


## Enable/disable magnetic attraction.[br]
## [param enabled]: Whether magnetic pull is active.
func set_magnetic_enabled(enabled: bool) -> void:
	magnetic_enabled = enabled


## Set magnetic strength.[br]
## [param strength]: Attraction strength in pixels/second^2.
func set_magnetic_strength(strength: float) -> void:
	magnetic_strength = strength


## Clear all items.[br]
## [param emit_signals]: Whether to emit signals.
func clear_all_items(emit_signals: bool = false) -> void:
	if emit_signals:
		for item in detected_items:
			item_lost.emit(item)
	
	detected_items.clear()
	collectible_items.clear()


## Internal: Handle item entering DETECTION area
func _on_detection_body_entered(body: Node) -> void:
	_handle_detected(body)

func _on_detection_area_entered(area: Node) -> void:
	_handle_detected(area)

func _on_detection_body_exited(body: Node) -> void:
	_handle_detection_lost(body)

func _on_detection_area_exited(area: Node) -> void:
	_handle_detection_lost(area)


## Internal: Handle item entering COLLECTION area
func _on_collection_body_entered(body: Node) -> void:
	_handle_collectible(body)

func _on_collection_area_entered(area: Node) -> void:
	_handle_collectible(area)

func _on_collection_body_exited(body: Node) -> void:
	_handle_collection_lost(body)

func _on_collection_area_exited(area: Node) -> void:
	_handle_collection_lost(area)


## Internal: Item detected (entered detection range)
func _handle_detected(item: Node) -> void:
	if detected_items.has(item):
		return
	
	# Apply filter
	if collection_filter.is_valid():
		if not collection_filter.call(item):
			return
	
	# Check limit
	if max_detected_items > 0 and detected_items.size() >= max_detected_items:
		detection_limit_reached.emit(item)
		return
	
	detected_items.append(item)
	item_detected.emit(item)


## Internal: Item lost from detection
func _handle_detection_lost(item: Node) -> void:
	if detected_items.has(item):
		detected_items.erase(item)
		item_lost.emit(item)


## Internal: Item entered collection range
func _handle_collectible(item: Node) -> void:
	# Must be detected first
	if not detected_items.has(item):
		return
	
	if collectible_items.has(item):
		return
	
	collectible_items.append(item)
	item_ready_to_collect.emit(item)
	
	# Auto-collect if in automatic mode
	if collection_mode == CollectionMode.AUTOMATIC:
		collect_item(item)


## Internal: Item left collection range
func _handle_collection_lost(item: Node) -> void:
	collectible_items.erase(item)


## Internal: Scan existing items in detection area
func _scan_existing_detected() -> void:
	if not detection_area:
		return
	
	if detect_bodies:
		for body in detection_area.get_overlapping_bodies():
			_handle_detected(body)
	
	if detect_areas:
		for area in detection_area.get_overlapping_areas():
			_handle_detected(area)


## Internal: Scan existing items in collection area
func _scan_existing_collectible() -> void:
	if not collection_area:
		return
	
	for body in collection_area.get_overlapping_bodies():
		_handle_collectible(body)
	
	for area in collection_area.get_overlapping_areas():
		_handle_collectible(area)


## Internal: Update magnetic attraction
func _update_magnetic_attraction(delta: float) -> void:
	if not owner is Node2D:
		return
	
	var owner_pos = (owner as Node2D).global_position
	
	for item in detected_items:
		if not is_instance_valid(item) or not item is Node2D:
			continue
		
		# Don't pull if already in collection range
		if collectible_items.has(item):
			continue
		
		var item_node = item as Node2D
		var to_player = owner_pos - item_node.global_position
		var distance = to_player.length()
		
		# Stop pulling when very close (let collection area handle it)
		if distance < magnetic_min_distance:
			continue
		
		var direction = to_player.normalized()
		
		# Stronger pull when closer
		var distance_factor = 1.0 - clampf(distance / get_range(), 0.0, 1.0)
		var pull_force = magnetic_strength * (1.0 + distance_factor) * delta
		
		# Apply movement
		var velocity = direction * pull_force
		item_node.global_position += velocity.limit_length(magnetic_max_speed * delta)


## Internal: Get closest detected item
func _get_closest_item() -> Node:
	if not owner is Node2D:
		return detected_items[0] if not detected_items.is_empty() else null
	
	var owner_node = owner as Node2D
	var closest: Node = null
	var min_dist = INF
	
	for item in detected_items:
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
	elif item.has_meta("item_type"):
		return item.get_meta("item_type")
	elif "type" in item:
		return item.get("type")
	else:
		return item.name


## Internal: Destroy collected item
func _destroy_item(item: Node) -> void:
	if not is_instance_valid(item):
		return
	
	if item.has_method("on_collected"):
		item.call("on_collected")
		return

	item.queue_free()


## Internal: Cleanup invalid items
func _cleanup_invalid_items() -> int:
	var removed = 0
	
	# Clean detected items
	var i = detected_items.size() - 1
	while i >= 0:
		var item = detected_items[i]
		if not is_instance_valid(item):
			detected_items.remove_at(i)
			item_lost.emit(item)
			removed += 1
		i -= 1
	
	# Clean collectible items
	i = collectible_items.size() - 1
	while i >= 0:
		var item = collectible_items[i]
		if not is_instance_valid(item):
			collectible_items.remove_at(i)
			removed += 1
		i -= 1
	
	return removed


## Internal: Detect and configure collision shape
func _detect_collision_shape() -> void:
	if not detection_area:
		return
	
	for child in detection_area.get_children():
		if child is CollisionShape2D:
			collision_shape = child
			break
	
	if not collision_shape:
		push_warning("CollectionComponentV2: No CollisionShape2D found in detection_area")
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


## Internal: Update collision shape size
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
