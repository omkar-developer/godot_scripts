class_name FleeSteering
extends SteeringBehavior

var target: Node2D
var panic_distance := 200.0

func _init(_target: Node2D, _panic_distance := 200.0, _owner: Node2D = null, _movement: MovementComponent = null):
	super._init()
	target = _target
	panic_distance = _panic_distance
	owner = _owner
	movement = _movement

func calculate() -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO
		
	var to_target = target.global_position - owner.global_position
	var distance = to_target.length()
	
	# Only flee if within panic distance
	if distance > panic_distance:
		return Vector2.ZERO
		
	var desired = -to_target.normalized() * movement.speed  # Note the negative
	var steering = desired - movement.velocity
	return steering.limit_length(max_force)
