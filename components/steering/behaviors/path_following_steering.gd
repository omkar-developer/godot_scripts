class_name PathFollowingSteering
extends SteeringBehavior

var path_points: Array[Vector2] = []
var current_target_index := 0
var path_radius := 20.0
var predict_distance := 50.0
var path_completed := false
var waypoint_proximity_threshold := 5.0

signal reached_path_end

func _init(_path_points: Array[Vector2], _path_radius := 20.0, _owner: Node2D = null, _movement: MovementComponent = null):
	super._init()
	path_points = _path_points
	path_radius = _path_radius
	owner = _owner
	movement = _movement
	path_completed = false

func calculate() -> Vector2:
	# If path is completed, apply full braking force to stop agent
	if path_completed:
		if movement.velocity.length_squared() > 0.01:  # Still moving
			# Calculate steering force to counter current velocity
			var _desired_velocity = Vector2.ZERO
			var _steering = _desired_velocity - movement.velocity
			return _steering.limit_length(max_force)
		else:  # Already stopped
			movement.velocity = Vector2.ZERO
			return Vector2.ZERO
	
	# Handle empty path case
	if path_points.is_empty():
		return Vector2.ZERO
	
	# Check if we've reached the current target
	var current_target = path_points[current_target_index]
	var to_target = current_target - owner.global_position
	var distance_to_target = to_target.length()
	
	# Handle waypoint arrival
	if distance_to_target <= path_radius:
		current_target_index += 1
		
		# Check if path is completed
		if current_target_index >= path_points.size():
			path_completed = true
			reached_path_end.emit()
			# Immediately start braking instead of returning ZERO
			var _desired_velocity = Vector2.ZERO
			var _steering = _desired_velocity - movement.velocity
			return _steering.limit_length(max_force)
	
	# Calculate target point with lookahead
	var target_point = current_target
	if current_target_index < path_points.size() - 1:
		var next_point = path_points[current_target_index + 1]
		var segment_dir = (next_point - current_target).normalized()
		var dynamic_lookahead = clamp(movement.velocity.length() * 0.2, 10, predict_distance)
		var lookahead_candidate = current_target + segment_dir * dynamic_lookahead
		
		if owner.global_position.distance_to(lookahead_candidate) > path_radius:
			target_point = lookahead_candidate
	
	# Calculate desired velocity
	var to_target_point = target_point - owner.global_position
	var desired_velocity = to_target_point.normalized() * movement.speed
	
	# Apply braking when close to final target
	if current_target_index == path_points.size() - 1:
		var braking_distance = path_radius * 3.0
		if distance_to_target < braking_distance:
			desired_velocity *= clamp(distance_to_target / braking_distance, 0.1, 1.0)
	
	# Calculate steering force
	var steering = desired_velocity - movement.velocity
	return steering.limit_length(max_force)

func set_new_path(new_path: Array[Vector2]):
	path_points = new_path
	current_target_index = 0
	path_completed = false
