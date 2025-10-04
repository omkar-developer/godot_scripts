class_name FlowFieldComponent
extends RefCounted

## Component that makes MovementComponent follow a flow field
## Requires: MovementComponent (https://github.com/your-repo/movement-component)
## Usage:
##   var movement = MovementComponent.new(self, 100.0)
##   var flowfield = FlowFieldComponent.new(movement, flow_field_manager)
##   flowfield.update(delta)

var owner: Node2D
var movement: MovementComponent
var flow_field: FlowFieldManager

var current_cell: Vector2i = Vector2i(-1, -1)
var target_cell: Vector2i = Vector2i(-1, -1)
var blocked_timer: float = 0.0
var moving_to_target: bool = false

# Configuration
var reroute_timeout: float = 0.4
var allow_backward_movement: bool = true
var use_collision_avoidance: bool = true  # Set false for simple following
var flowfield_enabled: bool = true

func _init(_movement: MovementComponent, _flow_field: FlowFieldManager = null):
	self.owner = _movement.owner
	self.movement = _movement
	self.flow_field = _flow_field
	
	if flow_field and owner:
		current_cell = flow_field.world_to_cell(owner.global_position)
		if use_collision_avoidance:
			flow_field.mark_cell(current_cell, true)

func cleanup():
	"""Call this in owner's _exit_tree() or when component is no longer needed"""
	if flow_field and use_collision_avoidance:
		if target_cell.x >= 0 and target_cell != current_cell:
			flow_field.mark_cell(target_cell, false)
		if current_cell.x >= 0:
			flow_field.mark_cell(current_cell, false)

func update(delta: float):
	if not flowfield_enabled or flow_field == null or not is_instance_valid(owner):
		return
	
	if use_collision_avoidance:
		_update_with_avoidance(delta)
	else:
		_update_simple(delta)
	
	movement.update(delta)

func _update_simple(delta: float):
	"""Simple following without collision avoidance"""
	var flow := flow_field.get_flow_at_position(owner.global_position)
	
	# Reached goal
	if flow.length_squared() < 0.01:
		owner.queue_free()
		return
	
	# Set movement direction to follow flow
	movement.direction = flow

func _update_with_avoidance(delta: float):
	"""Advanced following with collision avoidance and pathfinding"""
	var flow := flow_field.get_flow_at_position(owner.global_position)
	
	# Reached goal
	if flow.length_squared() < 0.01:
		owner.queue_free()
		return
	
	var cell_now = flow_field.world_to_cell(owner.global_position)
	
	# Check if we reached target cell
	if moving_to_target and cell_now == target_cell:
		if current_cell.x >= 0 and current_cell != target_cell:
			flow_field.mark_cell(current_cell, false)
		current_cell = target_cell
		target_cell = Vector2i(-1, -1)
		moving_to_target = false
		blocked_timer = 0.0
	
	# Need to pick new target cell
	if not moving_to_target:
		var next_cell = flow_field.world_to_cell(owner.global_position + flow.normalized() * flow_field.cell_size)
		
		if next_cell == current_cell:
			next_cell = flow_field.world_to_cell(owner.global_position + flow.normalized() * flow_field.cell_size * 1.5)
		
		# Check if goal cell
		var next_cell_flow = flow_field.get_flow_at_cell(next_cell)
		var is_goal_cell = next_cell_flow.length_squared() < 0.01
		
		# Check if free
		if is_goal_cell or not flow_field.is_cell_occupied(next_cell):
			target_cell = next_cell
			if not is_goal_cell:
				flow_field.mark_cell(target_cell, true)
			moving_to_target = true
			blocked_timer = 0.0
		else:
			# Blocked! Try alternate
			blocked_timer += delta
			
			if blocked_timer >= reroute_timeout:
				var alternate = _find_alternate_cell()
				if alternate != current_cell and not flow_field.is_cell_occupied(alternate):
					target_cell = alternate
					flow_field.mark_cell(target_cell, true)
					moving_to_target = true
					blocked_timer = 0.0
				else:
					blocked_timer = 0.0
			
			# Can't move this frame
			movement.direction = Vector2.ZERO
			return
	
	# Move toward target
	if moving_to_target:
		var target_world = flow_field.cell_to_world(target_cell)
		movement.direction = (target_world - owner.global_position)

func _find_alternate_cell() -> Vector2i:
	var neighbors = [
		Vector2i(current_cell.x + 1, current_cell.y),
		Vector2i(current_cell.x - 1, current_cell.y),
		Vector2i(current_cell.x, current_cell.y + 1),
		Vector2i(current_cell.x, current_cell.y - 1),
		Vector2i(current_cell.x + 1, current_cell.y + 1),
		Vector2i(current_cell.x - 1, current_cell.y - 1),
		Vector2i(current_cell.x + 1, current_cell.y - 1),
		Vector2i(current_cell.x - 1, current_cell.y + 1),
	]
	
	var valid_alternates = []
	
	for neighbor in neighbors:
		if flow_field.is_cell_occupied(neighbor):
			continue
		
		var neighbor_flow = flow_field.get_flow_at_cell(neighbor)
		if neighbor_flow.length_squared() < 0.01:
			continue
		
		var neighbor_points_to = flow_field.world_to_cell(
			flow_field.cell_to_world(neighbor) + neighbor_flow.normalized() * flow_field.cell_size
		)
		
		if neighbor_points_to == current_cell and not allow_backward_movement:
			continue
		
		if flow_field.has_method("get_cost_at_cell"):
			var cost = flow_field.get_cost_at_cell(neighbor)
			valid_alternates.append({"cell": neighbor, "cost": cost})
		else:
			return neighbor
	
	if valid_alternates.size() > 0:
		valid_alternates.sort_custom(func(a, b): return a.cost < b.cost)
		return valid_alternates[0].cell
	
	return current_cell

func set_flow_field(new_flow_field: FlowFieldManager):
	"""Change the flow field this component follows"""
	cleanup()
	flow_field = new_flow_field
	if flow_field and owner:
		current_cell = flow_field.world_to_cell(owner.global_position)
		if use_collision_avoidance:
			flow_field.mark_cell(current_cell, true)
