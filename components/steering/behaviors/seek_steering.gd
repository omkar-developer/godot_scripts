class_name SeekSteering
extends SteeringBehavior

var target: Node2D
var effect_radius := 100.0

func _init(_target: Node2D, _owner: Node2D = null, _movement: MovementComponent = null):
	owner = _owner
	target = _target
	movement = _movement

func calculate() -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO
	if effect_radius > 0 and owner.global_position.distance_squared_to(target.global_position) > effect_radius:
		return Vector2.ZERO
	var desired = (target.global_position - owner.global_position).normalized() * movement.speed
	var steering = desired - movement.velocity
	return steering.limit_length(max_force)
