class_name SeperationSteering
extends SteeringBehavior

var detection_area: Area2D
var separation_force_multiplier := 200.0

func _init(_detection_area: Area2D, _separation_force_multiplier := 200.0, _owner: Node2D = null, _movement: MovementComponent = null):
	super._init()
	detection_area = _detection_area
	separation_force_multiplier = _separation_force_multiplier
	owner = _owner
	movement = _movement

func calculate() -> Vector2:
	if not is_instance_valid(detection_area):
		return Vector2.ZERO
	
	var nearby_bodies = detection_area.get_overlapping_bodies()
	var separation_force = Vector2.ZERO
	var neighbor_count = 0
	
	for body in nearby_bodies:
		if body == owner:  # Don't separate from self
			continue
			
		var to_neighbor = owner.global_position - body.global_position
		var distance = to_neighbor.length()
		
		if distance > 0:  # Avoid division by zero
			# Force is stronger when neighbors are closer
			var force_magnitude = separation_force_multiplier / (distance * distance)
			separation_force += to_neighbor.normalized() * force_magnitude
			neighbor_count += 1
	
	if neighbor_count > 0:
		separation_force = separation_force.normalized() * max_force
	
	return separation_force