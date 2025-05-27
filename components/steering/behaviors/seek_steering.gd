class_name SeekSteering
extends RefCounted

var owner: Node2D
var target: Node2D
var movement: PhysicsMovementComponent
var max_force := 200.0

func _init(_owner: Node2D, _target: Node2D, _movement: PhysicsMovementComponent):
	owner = _owner
	target = _target
	movement = _movement

func calculate() -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO
	var desired = (target.global_position - owner.global_position).normalized() * movement.max_speed
	var steering = desired - movement.velocity
	return steering.limit_length(max_force)
