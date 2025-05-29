class_name SteeringBehavior
extends RefCounted

var owner: Node2D
var movement: MovementComponent
var max_force := 200.0

func _init(owner_node: Node2D = null, movement_comp: MovementComponent = null):
	setup(owner_node, movement_comp)

func setup(owner_node: Node2D, movement_comp: MovementComponent) -> void:
	owner = owner_node
	movement = movement_comp

func calculate() -> Vector2:
	return Vector2.ZERO
