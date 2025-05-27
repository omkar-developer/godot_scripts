class_name PhysicsMovementComponent
extends RefCounted

var owner: Node2D
var velocity := Vector2.ZERO
var acceleration := Vector2.ZERO
var max_speed := 200.0
var mass := 1.0
var damping := 0.1  # Air/fluid resistance coefficient
var ground_friction := 0.0  # Ground friction coefficient
var gravity_scale := 1.0  # How much gravity affects this object
var use_gravity := true
var gravity = Vector2(0, 980)  # 9.8 m/s² pointing downward

func _init(_owner: Node2D, _max_speed := 200.0, _mass := 1.0):
	self.owner = _owner
	self.max_speed = _max_speed
	self.mass = _mass

func apply_force(force: Vector2):
	acceleration += force / mass

func update(delta: float):
	if use_gravity:
		apply_force(gravity * gravity_scale * mass)
	
	# Apply damping (air/fluid resistance)
	if damping > 0.0:
		var damping_force = -velocity * damping
		apply_force(damping_force)
	
	# Update velocity
	velocity += acceleration * delta
	
	# Apply ground friction
	if ground_friction > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, ground_friction * delta)
	
	velocity = velocity.limit_length(max_speed)
	owner.position += velocity * delta
	acceleration = Vector2.ZERO  # reset each frame

func set_gravity_enabled(enabled: bool):
	use_gravity = enabled
