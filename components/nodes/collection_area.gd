@tool
@icon("res://scripts/icons/collection.svg")
class_name CollectionArea
extends Area2D

## Collection system using TargetingArea for detection + magnetic attraction.
##
## Features:
## - Large detection area for item tracking
## - Small collection trigger for actual pickup
## - Magnetic attraction to pull items
## - Group-based collection for screen-wide collection buffs
## - Automatic or manual collection modes

enum CollectionMode {
	AUTOMATIC,  ## Auto-collect when items enter collection trigger
	MAGNETIC    ## Items pulled magnetically, collected on trigger contact
}

@export_group("Areas")
## Large area for detecting items (if null, searches for TargetingArea child)
@export var detection_area: TargetingArea = null

@export_group("Collection Settings")
@export var collection_mode: CollectionMode = CollectionMode.MAGNETIC
## Automatically collect items when they enter the collection trigger
@export var auto_collect: bool = true
## Range for collection trigger
@export var collection_range: float = 100.0:
	set(v):
		collection_range = v
		_update_collision_shape(collection_range)

## Group name for screen-wide collection
@export var item_group_name: String = "collectible"

@export_group("Magnetic Attraction")
@export var magnetic_enabled: bool = true

## Base attraction force (pixels/second^2)
@export var magnetic_strength: float = 300.0

## Maximum speed items can be pulled
@export var magnetic_max_speed: float = 400.0

## Stop pulling when items are this close (let collection trigger handle)
@export var magnetic_min_distance: float = 10.0

## Distance factor affects pull strength (closer = stronger)
@export var use_distance_scaling: bool = true

@export_group("Group Collection (Screen-wide)")
## Enable periodic group-based collection (for screen-wide collection buffs)
@export var group_collection_enabled: bool = false

## How often to scan for new items in group (seconds)
@export var group_scan_interval: float = 0.5

## Duration for group collection (0 = infinite, disabled by default)
@export var group_collection_duration: float = 0.0

@export_group("Collision")
@export var set_collision_flags: bool = true ## Set collision layers and masks for detection and trigger
@export_flags_2d_physics var target_collision_layer: int = 1 << 3: ## does not work on child/global targeting area
	set(v):
		target_collision_layer = v
		if not set_collision_flags:
			return
		collision_layer = v
		if detection_area:
			detection_area.collision_layer = v
			
@export_flags_2d_physics var target_collision_mask: int = 2: ## does not work on child/global targeting area
	set(v):
		target_collision_mask = v
		if not set_collision_flags:
			return
		collision_mask = v
		if detection_area:
			detection_area.collision_mask = v

## Optional filter function: func(item: Node) -> bool
var collection_filter: Callable = Callable()

## Items currently in collection trigger range (ready to collect)
var collectible_items: Array[Node2D] = []

## Items being pulled by group collection
var group_pulled_items: Array[Node2D] = []

## Internal timers
var _group_scan_timer: float = 0.0
var _group_duration_timer: float = 0.0

var collision_shape: CollisionShape2D

## Emitted when an item is collected
signal item_collected(item: Node, item_type: String)

## Emitted when an item enters detection range
signal item_detected(item: Node)

## Emitted when an item leaves detection range
signal item_lost(item: Node)

## Emitted when an item enters collection trigger
signal item_ready_to_collect(item: Node)

## Emitted when collection fails
signal collection_failed(item: Node, reason: String)

## Emitted when group collection starts
signal group_collection_started()

## Emitted when group collection ends
signal group_collection_ended()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_setup_detection_area()
	_setup_collection_trigger()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	if not detection_area:
		var found = get_node_or_null("TargetingArea")
		if not found:
			warnings.append("Missing TargetingArea child node. Add a TargetingArea as a child.")

	return warnings

func _setup_detection_area() -> void:
	# Find or expect TargetingArea
	if not detection_area:
		detection_area = get_node_or_null("TargetingArea")
	
	if not detection_area:
		push_warning("CollectionArea: No TargetingArea found. Add a TargetingArea child node.")
		return
	
	# Configure for collection (track all items)
	detection_area.target_count = 999  # Track all detected items
	detection_area.target_priority = TargetingArea.Priority.FIRST_SEEN
	detection_area.update_mode = TargetingArea.UpdateMode.ON_ENTER

	if set_collision_flags:
		detection_area.collision_layer = target_collision_layer
		detection_area.collision_mask = target_collision_mask
	
	# Connect signals
	detection_area.target_found.connect(_on_item_detected)
	detection_area.target_lost.connect(_on_item_lost)

func _setup_collection_trigger() -> void:
	for child in get_children():
		if child is CollisionShape2D:
			collision_shape = child

	_update_collision_shape(collection_range)
	if set_collision_flags:
		collision_layer = target_collision_layer
		collision_mask = target_collision_mask

	# Connect signals
	if body_entered.is_connected(_on_collection_trigger_entered):
		body_entered.disconnect(_on_collection_trigger_entered)
	if area_entered.is_connected(_on_collection_trigger_entered):
		area_entered.disconnect(_on_collection_trigger_entered)
	
	body_entered.connect(_on_collection_trigger_entered)
	area_entered.connect(_on_collection_trigger_entered)
	
	if body_exited.is_connected(_on_collection_trigger_exited):
		body_exited.disconnect(_on_collection_trigger_exited)
	if area_exited.is_connected(_on_collection_trigger_exited):
		area_exited.disconnect(_on_collection_trigger_exited)
	
	body_exited.connect(_on_collection_trigger_exited)
	area_exited.connect(_on_collection_trigger_exited)
	
	# Scan for items already overlapping after setup
	call_deferred("_scan_overlapping_items")

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# Update detection area
	if detection_area:
		detection_area.update(delta)
	
	# Handle magnetic attraction
	if magnetic_enabled:
		_update_magnetic_attraction(delta)
	
	# Handle group collection
	if group_collection_enabled:
		_update_group_collection(delta)

## Update magnetic attraction for detected items
func _update_magnetic_attraction(delta: float) -> void:
	if not detection_area:
		return
	
	var detected = detection_area.get_all_targets()
	var owner_pos = global_position
	
	for item in detected:
		if not is_instance_valid(item):
			continue
		
		# Skip if already in collection range
		if collectible_items.has(item):
			continue
		
		_apply_magnetic_pull(item, owner_pos, delta)
	
	# Also pull group items
	for item in group_pulled_items:
		if not is_instance_valid(item):
			continue
		
		_apply_magnetic_pull(item, owner_pos, delta)

## Apply magnetic pull to a single item
func _apply_magnetic_pull(item: Node2D, target_pos: Vector2, delta: float) -> void:
	var to_target = target_pos - item.global_position
	var distance = to_target.length()
	
	# Stop pulling when very close
	if distance < magnetic_min_distance:
		return
	
	var direction = to_target.normalized()
	var pull_strength = magnetic_strength
	
	# Scale by distance if enabled (closer = stronger)
	if use_distance_scaling and detection_area:
		var max_range = detection_area.get_range()
		var distance_factor = 1.0 - clampf(distance / max_range, 0.0, 1.0)
		pull_strength *= (1.0 + distance_factor)
	
	# Apply movement
	var velocity = direction * pull_strength * delta
	if item is CharacterBody2D:
		item.velocity = velocity.limit_length(magnetic_max_speed)
	elif item is RigidBody2D:
		item.apply_central_force(velocity)
	else:
		item.global_position += velocity.limit_length(magnetic_max_speed * delta)


## Update group-based collection (for screen-wide buffs)
func _update_group_collection(delta: float) -> void:
	# Update duration timer
	if group_collection_duration > 0.0:
		_group_duration_timer += delta
		if _group_duration_timer >= group_collection_duration:
			stop_group_collection()
			return
	
	# Update scan timer
	_group_scan_timer += delta
	if _group_scan_timer >= group_scan_interval:
		_group_scan_timer = 0.0
		_scan_group_items()

## Scan for items in group and add to pull list
func _scan_group_items() -> void:
	if not is_inside_tree():
		return
	
	var items = get_tree().get_nodes_in_group(item_group_name)
	
	for item in items:
		if not item is Node2D:
			continue
		
		# Skip if already being pulled
		if group_pulled_items.has(item):
			continue
		
		# Skip if already detected by normal area
		if detection_area and detection_area.has_target(item):
			continue
		
		# Apply filter
		if collection_filter.is_valid():
			if not collection_filter.call(item):
				continue
		
		group_pulled_items.append(item)

## Start group-based collection (screen-wide collection buff)
## [param duration]: How long to keep pulling (0 = until manually stopped)
## [param scan_interval]: How often to scan for new items
func start_group_collection(duration: float = 0.0, scan_interval: float = 0.5) -> void:
	group_collection_enabled = true
	group_collection_duration = duration
	group_scan_interval = scan_interval
	_group_duration_timer = 0.0
	_group_scan_timer = 0.0
	group_pulled_items.clear()
	
	# Immediately scan
	_scan_group_items()
	
	group_collection_started.emit()

## Stop group-based collection
func stop_group_collection() -> void:
	if not group_collection_enabled:
		return
	
	group_collection_enabled = false
	group_pulled_items.clear()
	_group_duration_timer = 0.0
	
	group_collection_ended.emit()

## Instantly collect all items in group (no pulling animation)
## [param group_name]: Group to collect from (uses item_group_name if empty)
## [return]: Number of items collected
func collect_all_in_group(group_name: String = "") -> int:
	if not is_inside_tree():
		return 0
	
	var target_group = group_name if not group_name.is_empty() else item_group_name
	var items = get_tree().get_nodes_in_group(target_group)
	var collected = 0
	
	for item in items:
		# Apply filter
		if collection_filter.is_valid():
			if not collection_filter.call(item):
				continue
		
		if _collect_item(item):
			collected += 1
	
	return collected

## Collect a specific item
func collect_item(item: Node) -> bool:
	return _collect_item(item)

## Internal: Collect item and emit signals
func _collect_item(item: Node) -> bool:
	if not is_instance_valid(item):
		return false
	
	# Apply filter
	if collection_filter.is_valid():
		if not collection_filter.call(item):
			collection_failed.emit(item, "Failed filter check")
			return false
	
	# Get item type
	var item_type = _get_item_type(item)
	
	# Remove from tracking
	collectible_items.erase(item)
	group_pulled_items.erase(item)
	
	# Emit signal before destroying
	item_collected.emit(item, item_type)
	
	# Destroy/hide item
	_destroy_item(item)
	
	return true

## Signal handlers
func _on_item_detected(item: Node2D) -> void:
	item_detected.emit(item)

func _on_item_lost(item: Node2D) -> void:
	collectible_items.erase(item)
	item_lost.emit(item)

func _on_collection_trigger_entered(item: Node) -> void:
	if not is_instance_valid(item):
		return
	
	# Must be detected or in group pull list
	var is_tracked = false
	if detection_area and detection_area.has_target(item):
		is_tracked = true
	elif group_pulled_items.has(item):
		is_tracked = true
	
	if not is_tracked:
		return
	
	if collectible_items.has(item):
		return
	
	collectible_items.append(item)
	item_ready_to_collect.emit(item)
	
	# Auto-collect if enabled
	if auto_collect:
		_collect_item(item)

func _on_collection_trigger_exited(item: Node) -> void:
	collectible_items.erase(item)

## Scan for items already overlapping the collection trigger
func _scan_overlapping_items() -> void:
	# Check overlapping bodies
	for body in get_overlapping_bodies():
		_on_collection_trigger_entered(body)
	
	# Check overlapping areas
	for area in get_overlapping_areas():
		_on_collection_trigger_entered(area)

## Utility functions
func _get_item_type(item: Node) -> String:
	if "item_type" in item:
		return item.get("item_type")
	if item.has_meta("item_type"):
		return item.get_meta("item_type")
	if "type" in item:
		return item.get("type")
	return item.name

func _destroy_item(item: Node) -> void:
	if not is_instance_valid(item):
		return
	
	if item.has_method("on_collected"):
		item.call("on_collected")
		return
	
	item.queue_free()

## Public API
func set_collection_filter(filter_func: Callable) -> void:
	collection_filter = filter_func
	
	# Also set on detection area
	if detection_area:
		detection_area.set_target_filter(filter_func)

func clear_collection_filter() -> void:
	collection_filter = Callable()
	
	if detection_area:
		detection_area.clear_target_filter()

func get_detected_count() -> int:
	return detection_area.get_target_count() if detection_area else 0

func get_collectible_count() -> int:
	return collectible_items.size()

func get_detected_items() -> Array[Node2D]:
	return detection_area.get_all_targets() if detection_area else []

func get_collectible_items() -> Array[Node2D]:
	return collectible_items.duplicate()

## Update collision shape size based on range
func _update_collision_shape(range_value: float) -> void:
	if not collision_shape or not collision_shape.shape:
		return

	var scaled_range := range_value
	var shape = collision_shape.shape

	if shape is CapsuleShape2D:
		shape.radius = scaled_range
		shape.height = scaled_range * 2
	elif shape is CircleShape2D:
		shape.radius = scaled_range
	elif shape is RectangleShape2D:
		shape.size = Vector2(scaled_range * 2, scaled_range * 2)
	
	# Rescan for overlapping items after shape change (runtime updates)
	if is_inside_tree():
		call_deferred("_scan_overlapping_items")
