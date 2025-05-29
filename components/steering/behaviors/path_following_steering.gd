class_name PathFollowingSteering
extends SteeringBehavior

var path_points: Array[Vector2] = []
var current_target_index := 0
var path_radius := 20.0  # How close to get to each point before moving to next
var predict_distance := 50.0  # How far ahead to look on path

func _init(_path_points: Array[Vector2], _path_radius := 20.0, _owner: Node2D = null, _movement: MovementComponent = null):
	super._init()
	path_points = _path_points
	path_radius = _path_radius
	owner = _owner
	movement = _movement

func calculate() -> Vector2:
	if path_points.is_empty():
		return Vector2.ZERO
	
	# Check if we've reached the current target
	if current_target_index < path_points.size():
		var current_target = path_points[current_target_index]
		var distance_to_target = owner.global_position.distance_to(current_target)
		
		if distance_to_target < path_radius:
			current_target_index += 1
			# Loop back to start if desired
			if current_target_index >= path_points.size():
				current_target_index = 0  # Remove this line if you don't want looping
	
	# Find the target point on the path
	var target_point: Vector2
	if current_target_index < path_points.size():
		target_point = path_points[current_target_index]
		
		# Look ahead on the path for smoother following
		if current_target_index + 1 < path_points.size():
			var next_point = path_points[current_target_index + 1]
			var direction_to_next = (next_point - target_point).normalized()
			target_point += direction_to_next * predict_distance
	else:
		# Reached end of path
		return Vector2.ZERO
	
	# Seek toward the target point
	var desired = (target_point - owner.global_position).normalized() * movement.speed
	var steering = desired - movement.velocity
	
	return steering.limit_length(max_force)