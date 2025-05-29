class_name WanderSteering
extends SteeringBehavior

var wander_radius := 50.0
var wander_distance := 80.0
var wander_jitter := 30.0
var wander_target := Vector2.ZERO

func _init(_wander_radius := 50.0, _wander_distance := 80.0, _wander_jitter := 30.0, _owner: Node2D = null, _movement: MovementComponent = null):
	super._init()
	wander_radius = _wander_radius
	wander_distance = _wander_distance
	wander_jitter = _wander_jitter
	owner = _owner
	movement = _movement
	
	# Initialize random wander target
	wander_target = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * wander_radius

func calculate() -> Vector2:
	# Add random jitter to wander target
	wander_target += Vector2(
		randf_range(-wander_jitter, wander_jitter),
		randf_range(-wander_jitter, wander_jitter)
	)
	
	# Keep wander target on circle
	wander_target = wander_target.normalized() * wander_radius
	
	# Get wander target position in world space
	var velocity_direction = movement.velocity.normalized()
	if velocity_direction == Vector2.ZERO:
		velocity_direction = Vector2.RIGHT  # Default direction
	
	var circle_center = owner.global_position + velocity_direction * wander_distance
	var world_target = circle_center + wander_target
	
	# Calculate steering force toward wander target
	var desired = (world_target - owner.global_position).normalized() * movement.speed
	var steering = desired - movement.velocity
	
	return steering.limit_length(max_force)