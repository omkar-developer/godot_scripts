class_name SteeringManagerComponent
extends RefCounted

var steering_behaviors: Array[RefCounted] = []
var movement: PhysicsMovementComponent

func _init(_movement: PhysicsMovementComponent):
	movement = _movement

func add_behavior(behavior: RefCounted, weight: float = 1.0):
	steering_behaviors.append({"behavior": behavior, "weight": weight})

func update(delta: float):
	var total_force := Vector2.ZERO
	for behavior_data in steering_behaviors:
		var behavior = behavior_data["behavior"]
		var weight = behavior_data["weight"]
		if "calculate" in behavior:
			total_force += behavior.calculate() * weight
	
	movement.apply_force(total_force)
	movement.update(delta)
