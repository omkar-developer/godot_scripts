class_name PhysicsMovementComponent
extends RefCounted

var owner: Node2D
var movement: MovementComponent
var acceleration := Vector2.ZERO
var constant_acceleration := Vector2.ZERO

# Limits
var mass := 1.0

# Forces
var friction := 0.0
var damping := 0.0

# Gravity
var use_gravity := false
var gravity_scale := 1.0
var gravity := Vector2(0, 980)

func _init(_movement: MovementComponent, _mass := 1.0, _use_gravity := false):
	movement = _movement
	use_gravity = _use_gravity
	owner = _movement.owner
	mass = max(_mass, 0.0001)  # prevent divide-by-zero

func apply_force(force: Vector2):
	acceleration += force / mass

func apply_impulse(impulse: Vector2):
	movement.velocity += impulse

func set_constant_velocity(new_velocity: Vector2):
	movement.velocity = new_velocity

func get_constant_velocity():
	return movement.velocity

func set_constant_acceleration(new_acceleration: Vector2):
	constant_acceleration = new_acceleration

func set_friction_seconds(time: float):
	if time > 0:
		friction = movement.velocity.length() / time
	else:
		friction = 0.0

func update(delta: float):
	if use_gravity:
		apply_force(gravity * gravity_scale * mass)

	# Damping like air resistance
	if damping > 0.0:
		apply_force(-movement.velocity * damping)

	# Apply acceleration forces
	movement.velocity += acceleration * delta
	movement.velocity += constant_acceleration * delta

	# Apply friction
	if friction > 0.0:
		movement.velocity = movement.velocity.move_toward(Vector2.ZERO, friction * delta)

	# Limit velocity using the function from MovementComponent
	movement.limit_velocity()
	
	# Reset frame-based acceleration
	acceleration = Vector2.ZERO
