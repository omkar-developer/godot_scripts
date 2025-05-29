class_name PhysicsQuerySeparation
extends SteeringBehavior

var detection_radius := 80.0
var collision_mask := 2  # Physics layer for other agents
var separation_force_multiplier := 150.0

func _init(_detection_radius := 80.0, _collision_mask := 2, _separation_force_multiplier := 150.0, _owner: Node2D = null, _movement: MovementComponent = null):
	super._init()
	detection_radius = _detection_radius
	collision_mask = _collision_mask
	separation_force_multiplier = _separation_force_multiplier
	owner = _owner
	movement = _movement

func calculate() -> Vector2:
	var space_state = owner.get_world_2d().direct_space_state
	
	# Create a circle query to find nearby agents
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = detection_radius
	
	query.shape = circle_shape
	query.transform = Transform2D(0, owner.global_position)
	query.collision_mask = collision_mask
	
	var results = space_state.intersect_shape(query)
	
	var separation_force = Vector2.ZERO
	var neighbor_count = 0
	
	for result in results:
		var collider = result.collider
		if collider == owner:  # Don't separate from self
			continue
			
		var to_neighbor = owner.global_position - collider.global_position
		var distance = to_neighbor.length()
		
		if distance > 0:
			# Force is stronger when neighbors are closer
			var force_magnitude = (detection_radius - distance) / detection_radius
			separation_force += to_neighbor.normalized() * force_magnitude * separation_force_multiplier
			neighbor_count += 1
	
	if neighbor_count > 0:
		return separation_force.limit_length(max_force)
	
	return Vector2.ZERO