class_name AlignmentSteering
extends SteeringBehavior

var detection_radius := 80.0
var collision_mask := 2

func _init(_detection_radius := 80.0, _collision_mask := 2, _owner: Node2D = null, _movement: MovementComponent = null):
	super._init()
	detection_radius = _detection_radius
	collision_mask = _collision_mask
	owner = _owner
	movement = _movement

func calculate() -> Vector2:
	var space_state = owner.get_world_2d().direct_space_state
	
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = detection_radius
	
	query.shape = circle_shape
	query.transform = Transform2D(0, owner.global_position)
	query.collision_mask = collision_mask
	
	var results = space_state.intersect_shape(query)
	
	var average_velocity = Vector2.ZERO
	var neighbor_count = 0
	
	for result in results:
		var neighbor = result.collider
		if neighbor == owner:
			continue
			
		# Try to get neighbor's movement component
		if neighbor.has_method("get_velocity"):
			average_velocity += neighbor.get_velocity()
		elif neighbor.has_meta("velocity"):
			average_velocity += neighbor.get_meta("velocity")
		
		neighbor_count += 1
	
	if neighbor_count > 0:
		average_velocity /= neighbor_count
		var desired = average_velocity.normalized() * movement.speed
		var steering = desired - movement.velocity
		return steering.limit_length(max_force)
	
	return Vector2.ZERO