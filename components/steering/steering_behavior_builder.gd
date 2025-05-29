class_name SteeringBehaviorBuilder
extends RefCounted

# Builder settings
var owner_node: Node2D
var movement_comp: MovementComponent
var steering_manager: SteeringManagerComponent

# Common parameters
var obstacle_collision_mask := 1
var agent_collision_mask := 2
var ray_length := 100.0
var separation_radius := 60.0
var max_speed := 200.0

func _init(_owner: Node2D, _movement: MovementComponent, _steering_manager: SteeringManagerComponent):
	owner_node = _owner
	movement_comp = _movement
	steering_manager = _steering_manager

# Configuration methods
func set_obstacle_mask(mask: int) -> SteeringBehaviorBuilder:
	obstacle_collision_mask = mask
	return self

func set_agent_mask(mask: int) -> SteeringBehaviorBuilder:
	agent_collision_mask = mask
	return self

func set_ray_length(length: float) -> SteeringBehaviorBuilder:
	ray_length = length
	return self

func set_separation_radius(radius: float) -> SteeringBehaviorBuilder:
	separation_radius = radius
	return self

# Preset behavior combinations
func basic_ai(target: Node2D, arrive_radius := 100.0, stop_radius := 15.0) -> SteeringBehaviorBuilder:
	"""Basic AI: Arrive + Obstacle Avoidance"""
	steering_manager.add_behavior(
		ArriveSteering.new(target, arrive_radius, stop_radius, owner_node, movement_comp), 
		1.0
	)
	steering_manager.add_behavior(
		OptimizedRaycastAvoidance.new(ray_length, obstacle_collision_mask, owner_node, movement_comp), 
		2.0
	)
	return self

func flocking(target: Node2D = null, cohesion_radius := 100.0) -> SteeringBehaviorBuilder:
	"""Flocking: Separation + Alignment + Cohesion + Obstacle Avoidance"""
	
	# Separation - avoid crowding
	steering_manager.add_behavior(
		PhysicsQuerySeparation.new(separation_radius, agent_collision_mask, 150.0, owner_node, movement_comp),
		1.5
	)
	
	# Alignment - match velocity with neighbors
	steering_manager.add_behavior(
		AlignmentSteering.new(cohesion_radius, agent_collision_mask, owner_node, movement_comp),
		1.0
	)
	
	# Cohesion - stay with group
	steering_manager.add_behavior(
		CohesionSteering.new(cohesion_radius, agent_collision_mask, owner_node, movement_comp),
		1.2
	)
	
	# Obstacle avoidance
	steering_manager.add_behavior(
		OptimizedRaycastAvoidance.new(ray_length, obstacle_collision_mask, owner_node, movement_comp),
		2.0
	)
	
	# Optional target seeking
	if target:
		steering_manager.add_behavior(
			SeekSteering.new(target, owner_node, movement_comp),
			0.3
		)
	
	return self

func patrol(path_points: Array[Vector2], path_radius := 25.0) -> SteeringBehaviorBuilder:
	"""Patrol: Path Following + Obstacle Avoidance"""
	steering_manager.add_behavior(
		PathFollowingSteering.new(path_points, path_radius, owner_node, movement_comp),
		1.0
	)
	steering_manager.add_behavior(
		OptimizedRaycastAvoidance.new(ray_length, obstacle_collision_mask, owner_node, movement_comp),
		1.8
	)
	return self

func predator(target: Node2D, hunt_radius := 200.0) -> SteeringBehaviorBuilder:
	"""Predator: Seek + Separation + Obstacle Avoidance"""
	
	# Seek target aggressively
	var seek_behavior = SeekSteering.new(target, owner_node, movement_comp)
	seek_behavior.effect_radius = hunt_radius
	steering_manager.add_behavior(seek_behavior, 1.2)
	
	# Separate from other predators
	steering_manager.add_behavior(
		PhysicsQuerySeparation.new(separation_radius * 0.8, agent_collision_mask, 180.0, owner_node, movement_comp),
		1.0
	)
	
	# Avoid obstacles
	steering_manager.add_behavior(
		OptimizedRaycastAvoidance.new(ray_length, obstacle_collision_mask, owner_node, movement_comp),
		2.2
	)
	
	return self

func prey(threat: Node2D, panic_radius := 150.0, wander_strength := 0.5) -> SteeringBehaviorBuilder:
	"""Prey: Flee + Wander + Obstacle Avoidance"""
	
	# Flee from threat
	steering_manager.add_behavior(
		FleeSteering.new(threat, panic_radius, owner_node, movement_comp),
		2.0
	)
	
	# Wander when not fleeing
	steering_manager.add_behavior(
		WanderSteering.new(40.0, 80.0, 30.0, owner_node, movement_comp),
		wander_strength
	)
	
	# Avoid obstacles (higher priority when fleeing)
	steering_manager.add_behavior(
		OptimizedRaycastAvoidance.new(ray_length * 1.2, obstacle_collision_mask, owner_node, movement_comp),
		2.5
	)
	
	# Separate from other prey (panic effect)
	steering_manager.add_behavior(
		PhysicsQuerySeparation.new(separation_radius * 1.5, agent_collision_mask, 200.0, owner_node, movement_comp),
		1.3
	)
	
	return self

func guard(guard_position: Vector2, patrol_radius := 150.0, alert_radius := 200.0, threat: Node2D = null) -> SteeringBehaviorBuilder:
	"""Guard: Stay near position, chase threats when detected"""
	
	if threat and owner_node.global_position.distance_to(threat.global_position) < alert_radius:
		# Chase mode
		steering_manager.add_behavior(
			SeekSteering.new(threat, owner_node, movement_comp),
			1.5
		)
	else:
		# Patrol mode - stay near guard position
		var guard_target = Node2D.new()
		guard_target.global_position = guard_position
		steering_manager.add_behavior(
			ArriveSteering.new(guard_target, patrol_radius, 20.0, owner_node, movement_comp),
			1.0
		)
		steering_manager.add_behavior(
			WanderSteering.new(30.0, 60.0, 20.0, owner_node, movement_comp),
			0.3
		)
	
	# Always avoid obstacles
	steering_manager.add_behavior(
		OptimizedRaycastAvoidance.new(ray_length, obstacle_collision_mask, owner_node, movement_comp),
		2.0
	)
	
	return self

func explorer(exploration_bounds: Rect2) -> SteeringBehaviorBuilder:
	"""Explorer: Wander within bounds + Obstacle Avoidance"""
	steering_manager.add_behavior(
		BoundedWanderSteering.new(exploration_bounds, 50.0, 100.0, 40.0, owner_node, movement_comp),
		1.0
	)
	steering_manager.add_behavior(
		OptimizedRaycastAvoidance.new(ray_length, obstacle_collision_mask, owner_node, movement_comp),
		1.8
	)
	return self

# Utility methods for fine-tuning
func add_custom_behavior(behavior: SteeringBehavior, weight: float) -> SteeringBehaviorBuilder:
	steering_manager.add_behavior(behavior, weight)
	return self

func adjust_behavior_weight(behavior_type: String, new_weight: float) -> SteeringBehaviorBuilder:
	for behavior_data in steering_manager.steering_behaviors:
		var behavior = behavior_data[0]
		if behavior.get_script().get_global_name() == behavior_type:
			behavior_data[1] = new_weight
			break
	return self

func clear_behaviors() -> SteeringBehaviorBuilder:
	steering_manager.steering_behaviors.clear()
	return self

# Static factory method
static func create(owner: Node2D, movement: MovementComponent, _steering_manager: SteeringManagerComponent) -> SteeringBehaviorBuilder:
	return SteeringBehaviorBuilder.new(owner, movement, _steering_manager)