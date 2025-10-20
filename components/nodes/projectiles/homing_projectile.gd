class_name HomingProjectile
extends MovingProjectile

## Homing missile that seeks target with steering behavior.[br]
## Can have initial random/away phase before homing starts.[br]
## Perfect for guided missiles, magic missiles, seeking projectiles.

## Target to home towards (set by weapon at runtime)
var target: Node = null

@export_group("Homing Settings")
## Homing strength (0.0 = no homing, 1.0 = instant turn)
@export var homing_strength: float = 5.0

## Delay before homing starts (seconds)
@export var homing_delay: float = 0.0

## Minimum distance to target before stopping homing
@export var min_homing_distance: float = 10.0

## Whether homing is active (runtime)
var is_homing_active: bool = false


func _on_spawned() -> void:
	super._on_spawned()
	
	# Start homing immediately if no delay
	if homing_delay <= 0.0:
		is_homing_active = true


func _update_behavior(delta: float) -> void:
	# Check if homing should activate
	if not is_homing_active and age >= homing_delay:
		is_homing_active = true
	
	# Apply homing if active
	if is_homing_active and _should_home():
		_apply_homing(delta)
	
	# Move projectile
	super._update_behavior(delta)


func _should_home() -> bool:
	# Check if target is valid
	if not is_instance_valid(target):
		return false
	
	if not target is Node2D:
		return false
	
	# Check if close enough to stop homing
	var target_node = target as Node2D
	var distance = global_position.distance_to(target_node.global_position)
	
	return distance > min_homing_distance


func _apply_homing(delta: float) -> void:
	var target_node = target as Node2D
	
	# Calculate desired direction
	var desired_direction = (target_node.global_position - global_position).normalized()
	
	# Calculate desired velocity
	var desired_velocity = desired_direction * speed
	
	# Lerp current velocity towards desired (steering)
	velocity = velocity.lerp(desired_velocity, homing_strength * delta)
	
	# Update direction
	direction = velocity.normalized()


## Set target and optionally start homing immediately
func set_target(new_target: Node, start_immediately: bool = false) -> void:
	target = new_target
	
	if start_immediately:
		is_homing_active = true
		homing_delay = 0.0


## Start homing immediately (ignores delay)
func activate_homing() -> void:
	is_homing_active = true
