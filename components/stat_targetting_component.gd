class_name StatTargetingComponent
extends TargetingComponent

## Stat-based targeting component that syncs detection range with a Stat.[br]
##[br]
## This component extends TargetingComponent to automatically adjust the Area2D's[br]
## collision shape radius based on a "range" Stat value. When the stat changes[br]
## (from upgrades, buffs, equipment, etc.), the detection area updates automatically.[br]
##[br]
## Supports CircleShape2D and RectangleShape2D collision shapes. For other shapes,[br]
## use the range_changed signal to implement custom scaling logic.

## Reference to the range stat
var range_stat: Stat = null

## Name of the range stat property on owner
var range_stat_name: String = "range"

## CollisionShape2D node to modify (auto-detected from detection_area)
var collision_shape: CollisionShape2D = null

## Base range multiplier (for scaling range stat value)
var range_multiplier: float = 1.0

## Whether to automatically update collision shape when range changes
var auto_update_shape: bool = true

## Shape type for easier handling
enum ShapeType {
	CIRCLE,      ## CircleShape2D - adjusts radius
	RECTANGLE,   ## RectangleShape2D - adjusts size
	CAPSULE,     ## CapsuleShape2D - adjusts radius
	CUSTOM       ## Other shape - use range_changed signal
}

## Current shape type (auto-detected)
var shape_type: ShapeType = ShapeType.CUSTOM

## Emitted when range stat changes and shape is updated.[br]
## [param new_range]: New range value (after multiplier).[br]
## [param old_range]: Previous range value (after multiplier).
signal range_changed(new_range: float, old_range: float)

## Constructor.[br]
## [param _owner]: The Object that owns this component (must have range stat).[br]
## [param _area]: Optional Area2D for detection (auto-detects if null).[br]
## [param _priority]: Initial targeting priority mode.[br]
## [param _range_stat_name]: Name of the range stat property on owner.
func _init(
	_owner: Object,
	_area: Area2D = null,
	_priority: Priority = Priority.CLOSEST,
	_range_stat_name: String = "range"
) -> void:
	super._init(_owner, _area, _priority)
	
	range_stat_name = _range_stat_name
	
	# Try to get range stat from owner
	range_stat = Stat.get_stat(owner, range_stat_name)
	
	if range_stat:
		range_stat.value_changed.connect(_on_range_changed)
	else:
		push_warning("StatTargetingComponent: Owner has no '%s' Stat property" % range_stat_name)
	
	# Auto-detect collision shape
	if detection_area:
		_detect_collision_shape()


## Override set_detection_area to also detect collision shape.
func set_detection_area(area: Area2D) -> void:
	super.set_detection_area(area)
	_detect_collision_shape()


## Internal: Auto-detect CollisionShape2D and its type.
func _detect_collision_shape() -> void:
	if not detection_area:
		return
	
	# Find CollisionShape2D child
	for child in detection_area.get_children():
		if child is CollisionShape2D:
			collision_shape = child
			break
	
	if not collision_shape:
		push_warning("StatTargetingComponent: No CollisionShape2D found in detection_area")
		return
	
	# Detect shape type
	var shape = collision_shape.shape
	if shape is CircleShape2D:
		shape_type = ShapeType.CIRCLE
	elif shape is RectangleShape2D:
		shape_type = ShapeType.RECTANGLE
	elif shape is CapsuleShape2D:
		shape_type = ShapeType.CAPSULE
	else:
		shape_type = ShapeType.CUSTOM
		push_warning("StatTargetingComponent: Custom shape detected, use range_changed signal for manual scaling")
	
	# Initialize shape to current range
	if range_stat and auto_update_shape:
		_update_collision_shape(range_stat.get_value())


## Internal: Handle range stat value changes.
func _on_range_changed(new_value: float, _new_max: float, old_value: float, _old_max: float) -> void:
	var new_range = new_value * range_multiplier
	var old_range = old_value * range_multiplier
	
	if auto_update_shape:
		_update_collision_shape(new_value)
	
	range_changed.emit(new_range, old_range)


## Internal: Update collision shape based on range value.
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
			# Scale both width and height equally
			rect.size = Vector2(scaled_range * 2, scaled_range * 2)
		
		ShapeType.CAPSULE:
			var capsule = collision_shape.shape as CapsuleShape2D
			capsule.radius = scaled_range
			# Keep height proportional or fixed as needed
			capsule.height = scaled_range * 2


## Get current range value (after multiplier).[br]
## [return]: Current range or 0.0 if no range stat.
func get_range() -> float:
	if range_stat:
		return range_stat.get_value() * range_multiplier
	return 0.0


## Get maximum range value (after multiplier).[br]
## [return]: Max range or 0.0 if no range stat.
func get_max_range() -> float:
	if range_stat:
		return range_stat.get_max() * range_multiplier
	return 0.0


## Manually set the collision shape to modify.[br]
## [param shape_node]: CollisionShape2D to control.
func set_collision_shape(shape_node: CollisionShape2D) -> void:
	collision_shape = shape_node
	_detect_collision_shape()
	
	# Update shape to current range
	if range_stat and auto_update_shape:
		_update_collision_shape(range_stat.get_value())


## Set range multiplier (for scaling stat value).[br]
## [param multiplier]: Multiplier to apply to range stat.[br]
## [param update_shape]: Whether to immediately update the collision shape.
func set_range_multiplier(multiplier: float, update_shape: bool = true) -> void:
	range_multiplier = multiplier
	
	if update_shape and range_stat and auto_update_shape:
		_update_collision_shape(range_stat.get_value())


## Enable or disable automatic shape updates.[br]
## [param enabled]: Whether to auto-update collision shape on stat changes.
func set_auto_update_shape(enabled: bool) -> void:
	auto_update_shape = enabled


## Manually force update collision shape to current range stat value.[br]
## Useful after disabling auto_update_shape and making manual changes.
func force_update_shape() -> void:
	if range_stat:
		_update_collision_shape(range_stat.get_value())


## Refresh stat reference from owner.[br]
## Call this if owner's stats were added/changed after initialization.
func refresh_range_stat() -> void:
	# Disconnect old stat
	if range_stat and range_stat.value_changed.is_connected(_on_range_changed):
		range_stat.value_changed.disconnect(_on_range_changed)
	
	# Get new stat reference
	range_stat = Stat.get_stat(owner, range_stat_name)
	
	if range_stat:
		range_stat.value_changed.connect(_on_range_changed)
		
		# Update shape to new stat value
		if auto_update_shape:
			_update_collision_shape(range_stat.get_value())
	else:
		push_warning("StatTargetingComponent: Owner has no '%s' Stat property" % range_stat_name)


## Set custom range stat name (if owner uses different naming).[br]
## [param stat_name]: Name of the range stat property.[br]
## [param refresh]: Whether to immediately refresh the stat reference.
func set_range_stat_name(stat_name: String, refresh: bool = true) -> void:
	range_stat_name = stat_name
	if refresh:
		refresh_range_stat()
