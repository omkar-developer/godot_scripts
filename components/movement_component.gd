class_name MovementComponent
extends RefCounted

# Types of supported owners
enum BodyType { NODE2D, AREA2D, CHARACTER_BODY_2D, PHYSICS_BODY_2D, UNKNOWN }

var speed: float = 100.0
var direction: Vector2 = Vector2.ZERO:
	set(value):
		direction = value
		normalized_direction = value.normalized()

var normalized_direction: Vector2 = Vector2.ZERO:
	set(value):
		normalized_direction = value
		velocity = normalized_direction * speed

var velocity: Vector2 = Vector2.ZERO
var owner: Node = null
var body_type: BodyType = BodyType.UNKNOWN
var enabled := true

func _init(_owner: Node, _speed := 100.0, _direction := Vector2.ZERO):
	set_body(_owner)
	speed = _speed
	if _direction != Vector2.ZERO:
		direction = _direction
	
func set_node2d(_owner: Node2D):
	owner = _owner
	body_type = BodyType.NODE2D

func set_area2d(_owner: Area2D):
	owner = _owner
	body_type = BodyType.AREA2D

func set_character_body_2d(_owner: CharacterBody2D):
	owner = _owner
	body_type = BodyType.CHARACTER_BODY_2D

func set_physics_body_2d(_owner: PhysicsBody2D):
	owner = _owner
	body_type = BodyType.PHYSICS_BODY_2D

func set_body(_owner: Node):
	owner = _owner
	if owner is CharacterBody2D:
		body_type = BodyType.CHARACTER_BODY_2D
	elif owner is PhysicsBody2D:
		body_type = BodyType.PHYSICS_BODY_2D
	elif owner is Area2D:
		body_type = BodyType.AREA2D
	elif owner is Node2D:
		body_type = BodyType.NODE2D
	else:
		body_type = BodyType.UNKNOWN

func update(delta: float):
	if not enabled:
		return
	if body_type == BodyType.NODE2D or body_type == BodyType.AREA2D:
		owner.position += velocity * delta
	elif body_type == BodyType.CHARACTER_BODY_2D:
		owner.velocity = velocity
		owner.move_and_slide()
	elif body_type == BodyType.PHYSICS_BODY_2D:
		owner.move_and_collide(velocity * delta)

func move_toward(target_position: Vector2):
	normalized_direction = (target_position - owner.global_position).normalized()

func limit_velocity():
	velocity = velocity.limit_length(speed)