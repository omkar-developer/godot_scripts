class_name ArriveSteering
extends RefCounted

var owner: Node2D
var target: Node2D
var movement: MovementComponent
var max_force := 200.0
var slowing_radius := 100.0

func _init(_owner: Node2D, _target: Node2D, _movement: MovementComponent):
	owner = _owner
	target = _target
	movement = _movement

func calculate() -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO
		
	var to_target = target.global_position - owner.global_position
	var distance = to_target.length()
	
	var desired_velocity: Vector2
	if distance < slowing_radius:
		desired_velocity = to_target.normalized() * movement.speed * (distance / slowing_radius)
	else:
		desired_velocity = to_target.normalized() * movement.speed
		
	var steering = desired_velocity - movement.velocity
	return steering.limit_length(max_force)
