class_name ArriveSteering
extends SteeringBehavior

var target: Node2D
var slow_radius := 100.0
var stop_radius := 10.0

func _init(_target: Node2D, _slow_radius := 100.0, _stop_radius := 10.0, _owner: Node2D = null, _movement: MovementComponent = null):
	super._init()
	target = _target
	owner = _owner
	movement = _movement
	slow_radius = _slow_radius
	stop_radius = _stop_radius

func calculate() -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO
		
	var to_target = target.global_position - owner.global_position
	var distance = to_target.length()
	
	# If we're very close to target, stop completely
	if distance < stop_radius:
		# Return force to counteract current velocity (bring to stop)
		return -movement.velocity
	
	# Get desired velocity
	var desired = to_target.normalized() * movement.speed
	
	# Scale speed based on distance if within slow_radius
	if distance < slow_radius:
		var speed_factor = (distance - stop_radius) / (slow_radius - stop_radius)
		speed_factor = max(0.0, speed_factor)  # Ensure non-negative
		desired *= speed_factor
	
	var steering = desired - movement.velocity
	return steering.limit_length(max_force)