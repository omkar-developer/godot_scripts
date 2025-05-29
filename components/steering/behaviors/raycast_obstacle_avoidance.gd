class_name RaycastObstacleAvoidance
extends SteeringBehavior

var ray_length := 100.0
var ray_count := 5  # Number of rays to cast (forward, left, right, etc.)
var avoidance_force_multiplier := 300.0
var collision_mask := 1  # Physics layer for obstacles

func _init(_ray_length := 100.0, _ray_count := 5, _collision_mask := 1, _owner: Node2D = null, _movement: MovementComponent = null):
	super._init()
	ray_length = _ray_length
	ray_count = _ray_count
	collision_mask = _collision_mask
	owner = _owner
	movement = _movement

func calculate() -> Vector2:
	var space_state = owner.get_world_2d().direct_space_state
	var avoidance_force = Vector2.ZERO
	
	# Get current movement direction, or use a default if stationary
	var forward_dir = movement.velocity.normalized()
	if forward_dir == Vector2.ZERO:
		forward_dir = Vector2.RIGHT  # Default forward direction
	
	# Cast multiple rays in different directions
	var ray_angles = []
	for i in range(ray_count):
		var angle_offset = (i - ray_count / 2) * (PI / 6)  # 30 degree spread between rays
		ray_angles.append(forward_dir.rotated(angle_offset))
	
	for i in range(ray_angles.size()):
		var ray_dir = ray_angles[i]
		var ray_end = owner.global_position + ray_dir * ray_length
		
		# Create ray query
		var query = PhysicsRayQueryParameters2D.create(
			owner.global_position, 
			ray_end,
			collision_mask
		)
		
		var result = space_state.intersect_ray(query)
		
		if result:
			var collision_point = result.position
			var distance = owner.global_position.distance_to(collision_point)
			var collision_normal = result.normal
			
			# Calculate avoidance force based on distance and ray direction
			var force_strength = (ray_length - distance) / ray_length
			var avoidance_dir = collision_normal  # Use surface normal for avoidance
			
			# Make center rays (forward-facing) have more influence
			var ray_weight = 1.0
			if i == ray_count / 2:  # Center ray
				ray_weight = 2.0
			elif abs(i - ray_count / 2) == 1:  # Adjacent to center
				ray_weight = 1.5
			
			avoidance_force += avoidance_dir * force_strength * ray_weight
	
	return (avoidance_force * avoidance_force_multiplier).limit_length(max_force)