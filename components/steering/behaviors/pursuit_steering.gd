class_name PursuitSteering
extends SteeringBehavior

var target: Node2D
var predict_time := 0.5

func _init(_target: Node2D, _owner: Node2D = null, _movement: MovementComponent = null):
	super._init()
	target = _target
	owner = _owner
	movement = _movement

func calculate() -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO
	
	# Predict future position if target has velocity component
	var future_position = target.global_position
	if target.has_method("get_velocity"):
		future_position += target.get_velocity() * predict_time
	
	var desired = (future_position - owner.global_position).normalized() * movement.speed
	var steering = desired - movement.velocity
	return steering.limit_length(max_force)
