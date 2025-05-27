class_name MovementComponent
extends RefCounted

var speed: float = 100.0
var direction: Vector2 = Vector2.RIGHT : 
	set(value):
		direction = value
		normalized_direction = value.normalized()
var normalized_direction: Vector2
var owner: Node2D

func _init(_owner: Node2D, _speed := 100.0, _direction := Vector2.RIGHT):
	self.owner = _owner
	self.speed = _speed
	self.direction = _direction

func update(delta: float):
	if owner:
		owner.position += normalized_direction * speed * delta
