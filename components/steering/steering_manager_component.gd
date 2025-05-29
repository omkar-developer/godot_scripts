class_name SteeringManagerComponent
extends RefCounted

var steering_behaviors: Array[Array] = []
var movement: MovementComponent
var owner: Node2D

func _init(_owner: Node2D, _movement: MovementComponent):
	owner = _owner
	movement = _movement

func add_behavior(behavior: SteeringBehavior, weight: float = 1.0) -> SteeringBehavior:
	behavior.setup(owner, movement)
	steering_behaviors.append([behavior, weight])
	return behavior

func update(delta: float):
	var total_force := Vector2.ZERO
	for behavior_data in steering_behaviors:
		var behavior = behavior_data[0]
		var weight = behavior_data[1]
		total_force += behavior.calculate() * weight
	
	movement.velocity += total_force * delta
	movement.limit_velocity()
	movement.update(delta)
