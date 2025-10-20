class_name MovingProjectile
extends BaseProjectile

## Standard moving projectile with velocity and pierce.[br]
## Optimized with simple pierce counter (no array tracking).[br]
## Perfect for bullets, arrows, simple projectiles.

## Velocity vector for movement (set by weapon at runtime)
var velocity: Vector2 = Vector2.ZERO

## Direction vector (set by weapon at runtime)
var direction: Vector2 = Vector2.RIGHT

## Speed value (set by weapon at runtime)
var speed: float = 300.0

@export_group("Pierce Settings")
## Maximum pierce count (-1 = infinite, 0 = destroy on first hit)
@export var max_pierce: int = 0

## Number of targets hit so far (runtime, don't set)
var hits: int = 0

@export_group("Bounce Settings")
## Whether this projectile can bounce off walls
@export var can_bounce: bool = false

## Maximum number of bounces (-1 = infinite, 0 = no bounce)
@export var max_bounces: int = 3

## Velocity dampening on bounce (1.0 = no loss, 0.5 = half speed)
@export var bounce_dampening: float = 1.0

## Whether to allow target hits after bouncing
@export var can_hit_after_bounce: bool = true

## Number of bounces so far (runtime)
var bounce_count: int = 0


func _update_behavior(delta: float) -> void:
	# Move projectile
	global_position += velocity * delta


func _update_rotation() -> void:
	if velocity.length_squared() > 0:
		rotation = velocity.angle()


func on_hit(target: Node) -> void:
	# Apply damage
	super.on_hit(target)
	
	# Increment hit counter
	hits += 1
	
	# Check if should destroy
	if _should_destroy_on_hit():
		_destroy()


func _should_destroy_on_hit() -> bool:
	# Infinite pierce, never destroy
	if max_pierce < 0:
		return false
	
	# Check if pierce exhausted
	return hits > max_pierce


## Set velocity directly
func set_velocity(vel: Vector2) -> void:
	velocity = vel
	direction = vel.normalized() if vel.length_squared() > 0 else Vector2.RIGHT
	speed = vel.length()


## Set direction and speed
func set_direction_speed(dir: Vector2, spd: float) -> void:
	direction = dir.normalized()
	speed = spd
	velocity = direction * speed


## Can this projectile pierce more?
func can_pierce_more() -> bool:
	if max_pierce < 0:
		return true
	return hits <= max_pierce
