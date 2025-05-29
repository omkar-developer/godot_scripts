class_name BoundedWanderSteering
extends WanderSteering

var bounds: Rect2

func _init(_bounds: Rect2, _wander_radius := 50.0, _wander_distance := 80.0, _wander_jitter := 30.0, _owner: Node2D = null, _movement: MovementComponent = null):
	super._init(_wander_radius, _wander_distance, _wander_jitter, _owner, _movement)
	bounds = _bounds

func calculate() -> Vector2:
	var base_force = super.calculate()
	
	# Add boundary forces if getting close to edges
	var boundary_force = Vector2.ZERO
	var pos = owner.global_position
	var boundary_margin = 50.0
	
	# Left boundary
	if pos.x < bounds.position.x + boundary_margin:
		boundary_force.x += (bounds.position.x + boundary_margin - pos.x) / boundary_margin
	
	# Right boundary  
	if pos.x > bounds.position.x + bounds.size.x - boundary_margin:
		boundary_force.x -= (pos.x - (bounds.position.x + bounds.size.x - boundary_margin)) / boundary_margin
	
	# Top boundary
	if pos.y < bounds.position.y + boundary_margin:
		boundary_force.y += (bounds.position.y + boundary_margin - pos.y) / boundary_margin
	
	# Bottom boundary
	if pos.y > bounds.position.y + bounds.size.y - boundary_margin:
		boundary_force.y -= (pos.y - (bounds.position.y + bounds.size.y - boundary_margin)) / boundary_margin
	
	return (base_force + boundary_force * max_force).limit_length(max_force)