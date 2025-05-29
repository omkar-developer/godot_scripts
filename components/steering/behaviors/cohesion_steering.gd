class_name CohesionSteering
extends SteeringBehavior

var detection_radius := 100.0
var collision_mask := 2

func _init(_detection_radius := 100.0, _collision_mask := 2, _owner: Node2D = null, _movement: MovementComponent = null):
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
	
	var center_of_mass = Vector2.ZERO
	var neighbor_count = 0
	
	for result in results:
		var neighbor = result.collider
		if neighbor == owner:
			continue
			
		center_of_mass += neighbor.global_position
		neighbor_count += 1
	
	if neighbor_count > 0:
		center_of_mass /= neighbor_count
		var desired = (center_of_mass - owner.global_position).normalized() * movement.speed
		var steering = desired - movement.velocity
		return steering.limit_length(max_force)
	
	return Vector2.ZERO