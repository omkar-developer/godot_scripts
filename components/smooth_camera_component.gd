class_name SmoothCameraComponent
extends RefCounted

## Advanced smooth camera system with multiple follow modes, deadzones, and effects.[br]
##[br]
## Professional camera component similar to Unity's Cinemachine. Supports smooth following,[br]
## look-ahead prediction, multi-target framing, boundaries, smooth zoom, and integration[br]
## with effects like screen shake. Perfect for dynamic 2D games.

## Camera follow modes
enum FollowMode {
	LOCK,           ## Hard lock to target (no smoothing)
	LERP,           ## Linear interpolation smoothing
	SPRING,         ## Physics-based spring damping
	PREDICT,        ## Look-ahead based on target velocity
	CUSTOM          ## Use custom follow function
}

## Deadzone shape types
enum DeadzoneShape {
	NONE,           ## No deadzone
	CIRCLE,         ## Circular deadzone
	BOX,            ## Rectangular deadzone
	CUSTOM          ## Custom deadzone check function
}

## Zoom modes
enum ZoomMode {
	FIXED,          ## Fixed zoom level
	SMOOTH,         ## Smooth zoom transitions
	AUTO_FIT,       ## Auto-zoom to fit all targets
	VELOCITY_BASED  ## Zoom based on target velocity
}

## Reference to Camera2D being controlled
var camera: Camera2D = null

## Primary follow target
var target: Node2D = null

## Additional targets for multi-target framing
var targets: Array[Node2D] = []

## Current follow mode
var follow_mode: FollowMode = FollowMode.SPRING

## Follow speed for LERP mode (0.0 to 1.0, higher = faster)
var follow_speed: float = 0.1

## Spring stiffness for SPRING mode (higher = tighter follow)
var spring_stiffness: float = 200.0

## Spring damping for SPRING mode (higher = less oscillation)
var spring_damping: float = 20.0

## Look-ahead distance multiplier for PREDICT mode
var predict_distance: float = 2.0

## Look-ahead smoothing speed
var predict_smoothing: float = 5.0

## Custom follow function: func(camera_pos: Vector2, target_pos: Vector2, delta: float) -> Vector2
var custom_follow_func: Callable = Callable()

## Deadzone settings
var deadzone_shape: DeadzoneShape = DeadzoneShape.CIRCLE
var deadzone_radius: float = 50.0  # For circle
var deadzone_size: Vector2 = Vector2(100, 100)  # For box
var deadzone_enabled: bool = true

## Custom deadzone check: func(camera_pos: Vector2, target_pos: Vector2) -> bool (true = in deadzone)
var custom_deadzone_func: Callable = Callable()

## Camera boundaries (world coordinates, Vector2.ZERO = no limit)
var boundary_min: Vector2 = Vector2.ZERO
var boundary_max: Vector2 = Vector2.ZERO
var boundaries_enabled: bool = false

## Zoom settings
var zoom_mode: ZoomMode = ZoomMode.SMOOTH
var target_zoom: float = 1.0
var zoom_speed: float = 5.0
var min_zoom: float = 0.5
var max_zoom: float = 3.0

## Auto-fit zoom settings (for multi-target)
var auto_fit_margin: float = 100.0  # Padding around targets
var auto_fit_enabled: bool = false

## Velocity-based zoom settings
var velocity_zoom_min_speed: float = 100.0
var velocity_zoom_max_speed: float = 500.0
var velocity_zoom_factor: float = 0.3

## Position offset applied before smoothing
var position_offset: Vector2 = Vector2.ZERO

## Rotation settings
var rotation_enabled: bool = false
var rotation_smoothing: float = 5.0
var target_rotation: float = 0.0

## Internal spring velocity
var _spring_velocity: Vector2 = Vector2.ZERO

## Current predicted offset
var _predict_offset: Vector2 = Vector2.ZERO

## Previous target position for velocity calculation
var _prev_target_pos: Vector2 = Vector2.ZERO

## Whether component is enabled
var enabled: bool = true

## Emitted when camera reaches target (within threshold)
signal camera_arrived()

## Emitted when target changes
signal target_changed(new_target: Node2D)

## Emitted when zoom changes significantly
signal zoom_changed(new_zoom: float)

## Emitted when camera hits boundary
signal boundary_hit(side: String)


func _init(_camera: Camera2D = null, _target: Node2D = null) -> void:
	if _camera:
		set_camera(_camera)
	if _target:
		set_target(_target)


## Set the camera to control.[br]
## [param cam]: Camera2D node.
func set_camera(cam: Camera2D) -> void:
	camera = cam
	if camera:
		target_zoom = camera.zoom.x


## Set the primary follow target.[br]
## [param new_target]: Node2D to follow.
func set_target(new_target: Node2D) -> void:
	target = new_target
	if target:
		_prev_target_pos = target.global_position
		target_changed.emit(target)


## Add additional target for multi-target framing.[br]
## [param additional_target]: Node2D to include in framing.
func add_target(additional_target: Node2D) -> void:
	if additional_target and not targets.has(additional_target):
		targets.append(additional_target)


## Remove target from multi-target list.[br]
## [param remove_target]: Node2D to remove.
func remove_target(remove_target: Node2D) -> void:
	targets.erase(remove_target)


## Clear all additional targets.
func clear_targets() -> void:
	targets.clear()


## Update camera (call in _process or _physics_process).[br]
## [param delta]: Time elapsed since last frame.
func update(delta: float) -> void:
	if not enabled or not camera or not is_instance_valid(camera):
		return
	
	if not target or not is_instance_valid(target):
		return
	
	# Calculate target position (average if multiple targets)
	var target_pos = _calculate_target_position()
	
	# Apply position offset
	target_pos += position_offset
	
	# Check deadzone
	if deadzone_enabled and _is_in_deadzone(camera.global_position, target_pos):
		# Update zoom and rotation even if in deadzone
		_update_zoom(delta)
		_update_rotation(delta)
		return
	
	# Calculate new camera position based on follow mode
	var new_pos = _calculate_follow_position(camera.global_position, target_pos, delta)
	
	# Apply boundaries
	if boundaries_enabled:
		new_pos = _apply_boundaries(new_pos)
	
	# Set camera position
	camera.global_position = new_pos
	
	# Update zoom
	_update_zoom(delta)
	
	# Update rotation
	_update_rotation(delta)
	
	# Update previous target position for velocity calculations
	_prev_target_pos = target.global_position


## Internal: Calculate average position of all targets
func _calculate_target_position() -> Vector2:
	if targets.is_empty():
		return target.global_position
	
	var sum = target.global_position
	var count = 1
	
	for t in targets:
		if is_instance_valid(t):
			sum += t.global_position
			count += 1
	
	return sum / count


## Internal: Check if camera is within deadzone
func _is_in_deadzone(cam_pos: Vector2, target_pos: Vector2) -> bool:
	match deadzone_shape:
		DeadzoneShape.NONE:
			return false
		
		DeadzoneShape.CIRCLE:
			var distance = cam_pos.distance_to(target_pos)
			return distance <= deadzone_radius
		
		DeadzoneShape.BOX:
			var offset = target_pos - cam_pos
			return abs(offset.x) <= deadzone_size.x / 2.0 and abs(offset.y) <= deadzone_size.y / 2.0
		
		DeadzoneShape.CUSTOM:
			if custom_deadzone_func.is_valid():
				return custom_deadzone_func.call(cam_pos, target_pos)
			return false
	
	return false


## Internal: Calculate follow position based on mode
func _calculate_follow_position(cam_pos: Vector2, target_pos: Vector2, delta: float) -> Vector2:
	match follow_mode:
		FollowMode.LOCK:
			return target_pos
		
		FollowMode.LERP:
			return cam_pos.lerp(target_pos, follow_speed)
		
		FollowMode.SPRING:
			return _calculate_spring_position(cam_pos, target_pos, delta)
		
		FollowMode.PREDICT:
			return _calculate_predict_position(cam_pos, target_pos, delta)
		
		FollowMode.CUSTOM:
			if custom_follow_func.is_valid():
				return custom_follow_func.call(cam_pos, target_pos, delta)
			return cam_pos
	
	return cam_pos


## Internal: Spring damping calculation
func _calculate_spring_position(cam_pos: Vector2, target_pos: Vector2, delta: float) -> Vector2:
	var displacement = target_pos - cam_pos
	var spring_force = displacement * spring_stiffness
	var damping_force = _spring_velocity * spring_damping
	
	var acceleration = spring_force - damping_force
	_spring_velocity += acceleration * delta
	
	return cam_pos + _spring_velocity * delta


## Internal: Predict position based on target velocity
func _calculate_predict_position(cam_pos: Vector2, target_pos: Vector2, delta: float) -> Vector2:
	# Calculate target velocity
	var velocity = (target.global_position - _prev_target_pos) / delta if delta > 0.0 else Vector2.ZERO
	
	# Calculate predicted offset
	var predicted_offset = velocity.normalized() * velocity.length() * predict_distance * 0.01
	
	# Smooth the predicted offset
	_predict_offset = _predict_offset.lerp(predicted_offset, predict_smoothing * delta)
	
	# Apply prediction
	var final_target = target_pos + _predict_offset
	
	# Smooth follow to predicted position
	return cam_pos.lerp(final_target, follow_speed)


## Internal: Apply boundary constraints
func _apply_boundaries(pos: Vector2) -> Vector2:
	var clamped = pos
	var hit_boundary = false
	
	if boundary_min != Vector2.ZERO or boundary_max != Vector2.ZERO:
		if pos.x < boundary_min.x:
			clamped.x = boundary_min.x
			hit_boundary = true
			boundary_hit.emit("left")
		elif pos.x > boundary_max.x:
			clamped.x = boundary_max.x
			hit_boundary = true
			boundary_hit.emit("right")
		
		if pos.y < boundary_min.y:
			clamped.y = boundary_min.y
			hit_boundary = true
			boundary_hit.emit("top")
		elif pos.y > boundary_max.y:
			clamped.y = boundary_max.y
			hit_boundary = true
			boundary_hit.emit("bottom")
	
	return clamped


## Internal: Update camera zoom
func _update_zoom(delta: float) -> void:
	if not camera:
		return
	
	var desired_zoom = target_zoom
	
	match zoom_mode:
		ZoomMode.FIXED:
			desired_zoom = target_zoom
		
		ZoomMode.SMOOTH:
			desired_zoom = target_zoom
		
		ZoomMode.AUTO_FIT:
			if auto_fit_enabled and not targets.is_empty():
				desired_zoom = _calculate_auto_fit_zoom()
		
		ZoomMode.VELOCITY_BASED:
			desired_zoom = _calculate_velocity_zoom()
	
	# Clamp zoom
	desired_zoom = clampf(desired_zoom, min_zoom, max_zoom)
	
	# Smooth zoom transition
	var current_zoom = camera.zoom.x
	var new_zoom = lerp(current_zoom, desired_zoom, zoom_speed * delta)
	
	if abs(new_zoom - current_zoom) > 0.01:
		camera.zoom = Vector2(new_zoom, new_zoom)
		zoom_changed.emit(new_zoom)


## Internal: Calculate auto-fit zoom to include all targets
func _calculate_auto_fit_zoom() -> float:
	if targets.is_empty():
		return target_zoom
	
	# Find bounding box of all targets
	var min_pos = target.global_position
	var max_pos = target.global_position
	
	for t in targets:
		if is_instance_valid(t):
			min_pos.x = minf(min_pos.x, t.global_position.x)
			min_pos.y = minf(min_pos.y, t.global_position.y)
			max_pos.x = maxf(max_pos.x, t.global_position.x)
			max_pos.y = maxf(max_pos.y, t.global_position.y)
	
	# Calculate required size with margin
	var size = max_pos - min_pos + Vector2(auto_fit_margin, auto_fit_margin)
	
	# Get viewport size
	var viewport_size = camera.get_viewport_rect().size
	
	# Calculate zoom to fit
	var zoom_x = viewport_size.x / size.x
	var zoom_y = viewport_size.y / size.y
	
	return minf(zoom_x, zoom_y)


## Internal: Calculate velocity-based zoom
func _calculate_velocity_zoom() -> float:
	if not target:
		return target_zoom
	
	# Calculate velocity
	var velocity = (target.global_position - _prev_target_pos).length()
	
	# Normalize velocity to 0-1 range
	var velocity_factor = clampf(
		(velocity - velocity_zoom_min_speed) / (velocity_zoom_max_speed - velocity_zoom_min_speed),
		0.0, 1.0
	)
	
	# Zoom out when moving fast
	return target_zoom - (velocity_factor * velocity_zoom_factor)


## Internal: Update camera rotation
func _update_rotation(delta: float) -> void:
	if not camera or not rotation_enabled:
		return
	
	var current_rotation = camera.rotation
	var new_rotation = lerp_angle(current_rotation, target_rotation, rotation_smoothing * delta)
	camera.rotation = new_rotation


## Set follow mode.[br]
## [param mode]: New FollowMode value.
func set_follow_mode(mode: FollowMode) -> void:
	follow_mode = mode
	_spring_velocity = Vector2.ZERO
	_predict_offset = Vector2.ZERO


## Set zoom level (smooth transition).[br]
## [param zoom]: New zoom level.
func set_zoom(zoom: float) -> void:
	target_zoom = clampf(zoom, min_zoom, max_zoom)


## Set zoom instantly (no smoothing).[br]
## [param zoom]: New zoom level.
func set_zoom_instant(zoom: float) -> void:
	target_zoom = clampf(zoom, min_zoom, max_zoom)
	if camera:
		camera.zoom = Vector2(target_zoom, target_zoom)


## Set camera boundaries.[br]
## [param min_bounds]: Minimum world coordinates.[br]
## [param max_bounds]: Maximum world coordinates.
func set_boundaries(min_bounds: Vector2, max_bounds: Vector2) -> void:
	boundary_min = min_bounds
	boundary_max = max_bounds
	boundaries_enabled = true


## Disable boundaries.
func disable_boundaries() -> void:
	boundaries_enabled = false


## Set deadzone parameters.[br]
## [param shape]: DeadzoneShape type.[br]
## [param radius_or_size]: Float for circle radius, Vector2 for box size.
func set_deadzone(shape: DeadzoneShape, radius_or_size: Variant = 50.0) -> void:
	deadzone_shape = shape
	deadzone_enabled = true
	
	if radius_or_size is float:
		deadzone_radius = radius_or_size
	elif radius_or_size is Vector2:
		deadzone_size = radius_or_size


## Disable deadzone.
func disable_deadzone() -> void:
	deadzone_enabled = false


## Shake camera (compatible with ScreenShakeComponent).[br]
## [param trauma]: Shake intensity (0.0 to 1.0).[br]
## [param duration]: Shake duration in seconds.
func shake(trauma: float, duration: float = 0.5) -> void:
	# This is a simple shake - use ScreenShakeComponent for advanced shakes
	if not camera:
		return
	
	var shake_offset = Vector2(
		randf_range(-20.0, 20.0),
		randf_range(-20.0, 20.0)
	) * trauma
	
	camera.offset += shake_offset
	
	# Reset offset after duration
	await camera.get_tree().create_timer(duration).timeout
	camera.offset = Vector2.ZERO


## Snap camera to target instantly (no smoothing).
func snap_to_target() -> void:
	if camera and target:
		camera.global_position = target.global_position + position_offset
		_spring_velocity = Vector2.ZERO
		_predict_offset = Vector2.ZERO


## Check if camera has reached target (within threshold).[br]
## [param threshold]: Distance threshold in pixels.[br]
## [return]: true if within threshold.
func has_arrived(threshold: float = 5.0) -> bool:
	if not camera or not target:
		return false
	
	return camera.global_position.distance_to(target.global_position) <= threshold


## Get current camera velocity.[br]
## [return]: Camera velocity vector.
func get_camera_velocity() -> Vector2:
	return _spring_velocity


## Enable/disable component.[br]
## [param is_enabled]: Whether component is active.
func set_enabled(is_enabled: bool) -> void:
	enabled = is_enabled


## Get component statistics.[br]
## [return]: Dictionary with camera info.
func get_stats() -> Dictionary:
	return {
		"follow_mode": FollowMode.keys()[follow_mode],
		"zoom": camera.zoom.x if camera else 0.0,
		"target_zoom": target_zoom,
		"position": camera.global_position if camera else Vector2.ZERO,
		"has_target": target != null,
		"additional_targets": targets.size(),
		"deadzone_enabled": deadzone_enabled,
		"boundaries_enabled": boundaries_enabled,
		"enabled": enabled
	}
