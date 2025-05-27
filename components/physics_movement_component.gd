class_name PhysicsMovementComponent
extends RefCounted

var owner: Node2D
var velocity := Vector2.ZERO
var acceleration := Vector2.ZERO
var max_speed := 200.0
var friction := 0.0

func _init(_owner: Node2D, _max_speed := 200.0):
	self.owner = _owner
	self.max_speed = _max_speed

func apply_force(force: Vector2):
	acceleration += force

func update(delta: float):
	velocity += acceleration * delta
	if friction > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	velocity = velocity.limit_length(max_speed)
	owner.position += velocity * delta
	acceleration = Vector2.ZERO
