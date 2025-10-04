class_name PlayerMovementComponent
extends RefCounted

var owner: Node2D
var speed: float = 400.0
var velocity: Vector2 = Vector2.ZERO

func _init(_owner: Node2D, _speed: float = 400.0):
	owner = _owner
	speed = _speed

func set_direction(dir: Vector2):
	velocity = dir.normalized() * speed

func stop():
	velocity = Vector2.ZERO

func update(delta: float):
	if owner:
		owner.position += velocity * delta
