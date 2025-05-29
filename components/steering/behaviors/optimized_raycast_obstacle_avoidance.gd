class_name OptimizedRaycastAvoidance
extends SteeringBehavior

var ray_length := 120.0
var side_ray_length := 80.0
var collision_mask := 1
var avoidance_multiplier := 400.0

# Cache for performance
var cached_space_state: PhysicsDirectSpaceState2D

func _init(_ray_length := 120.0, _collision_mask := 1, _owner: Node2D = null, _movement: MovementComponent = null):
	super._init()
	ray_length = _ray_length
	side_ray_length = _ray_length * 0.7
	collision_mask = _collision_mask
	owner = _owner
	movement = _movement

func calculate() -> Vector2:
	# Cache space state for better performance
	if not cached_space_state:
		cached_space_state = owner.get_world_2d().direct_space_state
	
	var velocity_dir = movement.velocity.normalized()
	if velocity_dir == Vector2.ZERO:
		velocity_dir = owner.transform.x  # Use object's facing direction
	
	var avoidance_force = Vector2.ZERO
	
	# Forward ray (most important)
	var forward_collision = cast_ray(owner.global_position, velocity_dir * ray_length)
	if forward_collision:
		var distance = owner.global_position.distance_to(forward_collision.position)
		var force_strength = (ray_length - distance) / ray_length
		avoidance_force += forward_collision.normal * force_strength * 2.0  # Double weight for forward
	
	# Left ray
	var left_dir = velocity_dir.rotated(-PI/4)  # 45 degrees left
	var left_collision = cast_ray(owner.global_position, left_dir * side_ray_length)
	if left_collision:
		var distance = owner.global_position.distance_to(left_collision.position)
		var force_strength = (side_ray_length - distance) / side_ray_length
		avoidance_force += Vector2(1, 0).rotated(velocity_dir.angle()) * force_strength  # Push right
	
	# Right ray
	var right_dir = velocity_dir.rotated(PI/4)  # 45 degrees right
	var right_collision = cast_ray(owner.global_position, right_dir * side_ray_length)
	if right_collision:
		var distance = owner.global_position.distance_to(right_collision.position)
		var force_strength = (side_ray_length - distance) / side_ray_length
		avoidance_force += Vector2(-1, 0).rotated(velocity_dir.angle()) * force_strength  # Push left
	
	return (avoidance_force * avoidance_multiplier).limit_length(max_force)

func cast_ray(from: Vector2, to_offset: Vector2) -> Dictionary:
	var to = from + to_offset
	var query = PhysicsRayQueryParameters2D.create(from, to, collision_mask)
	return cached_space_state.intersect_ray(query)