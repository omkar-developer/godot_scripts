extends Node
class_name FlowFieldMovement

## Node component that moves its parent following a flow field
## Usage: Add as child to any Node2D (Area2D, CharacterBody2D, etc.)

@export var speed: float = 80.0
@export var rotation_speed: float = 6.0
@export var reroute_timeout: float = 0.4
@export var allow_backward_movement: bool = true
@export var rotate_parent: bool = true  # Whether to rotate parent or not

var flow_field: FlowFieldManager
var current_cell: Vector2i = Vector2i(-1, -1)
var target_cell: Vector2i = Vector2i(-1, -1)
var blocked_timer: float = 0.0
var moving_to_target: bool = false

var parent_node: Node2D = null

func _ready() -> void:
	# Get parent as Node2D
	parent_node = get_parent() as Node2D
	if parent_node == null:		
		push_error("FlowFieldMovement: Parent must be a Node2D!")
		queue_free()
		return
	else:
		var ffield = parent_node.get("flow_field") as FlowFieldManager
		if ffield and not flow_field:
			flow_field = ffield		
	
	# Wait a frame for parent to be ready
	await get_tree().process_frame
	
	if flow_field:
		current_cell = flow_field.world_to_cell(parent_node.global_position)
		flow_field.mark_cell(current_cell, true)

func _exit_tree() -> void:
	if flow_field:
		if target_cell.x >= 0 and target_cell != current_cell:
			flow_field.mark_cell(target_cell, false)
		if current_cell.x >= 0:
			flow_field.mark_cell(current_cell, false)

func _process(delta: float) -> void:
	if parent_node == null or flow_field == null:
		return

	# Check if reached goal
	var flow := flow_field.get_flow_at_position(parent_node.global_position)
	if flow.length_squared() < 0.01:
		parent_node.queue_free()
		return

	var cell_now = flow_field.world_to_cell(parent_node.global_position)
	
	# Check if we reached our target cell
	if moving_to_target and cell_now == target_cell:
		# Arrived at target! Free old cell, update current
		if current_cell.x >= 0 and current_cell != target_cell:
			flow_field.mark_cell(current_cell, false)
		current_cell = target_cell
		target_cell = Vector2i(-1, -1)
		moving_to_target = false
		blocked_timer = 0.0

	# Need to pick a new target cell
	if not moving_to_target:
		# Get the cell flow points to
		var next_cell = flow_field.world_to_cell(parent_node.global_position + flow.normalized() * flow_field.cell_size)
		
		# If it's the same cell we're in, try to move forward
		if next_cell == current_cell:
			next_cell = flow_field.world_to_cell(parent_node.global_position + flow.normalized() * flow_field.cell_size * 1.5)
		
		# Check if this is the goal cell (flow from here is zero)
		var next_cell_flow = flow_field.get_flow_at_cell(next_cell)
		var is_goal_cell = next_cell_flow.length_squared() < 0.01
		
		# Check if next cell is free (goal cell is always "free")
		if is_goal_cell or not flow_field.is_cell_occupied(next_cell):
			# Reserve it and start moving (don't mark goal cell as occupied)
			target_cell = next_cell
			if not is_goal_cell:
				flow_field.mark_cell(target_cell, true)
			moving_to_target = true
			blocked_timer = 0.0
		else:
			# Blocked! Wait and try alternate
			blocked_timer += delta
			
			if blocked_timer >= reroute_timeout:
				var alternate = _find_alternate_cell()
				if alternate != current_cell and not flow_field.is_cell_occupied(alternate):
					# Found alternate! Reserve and move
					target_cell = alternate
					flow_field.mark_cell(target_cell, true)
					moving_to_target = true
					blocked_timer = 0.0
				else:
					# Still can't move, reset timer to try again
					blocked_timer = 0.0
			
			# Can't move this frame
			return

	# Move toward target cell
	if moving_to_target:
		var target_world = flow_field.cell_to_world(target_cell)
		var direction = (target_world - parent_node.global_position).normalized()
		parent_node.global_position += direction * speed * delta

		# Smooth rotation
		if rotate_parent:
			var target_angle = direction.angle()
			parent_node.rotation = lerp_angle(parent_node.rotation, target_angle, rotation_speed * delta)


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
		# Must not be occupied
		if flow_field.is_cell_occupied(neighbor):
			continue
		
		# Must have valid flow
		var neighbor_flow = flow_field.get_flow_at_cell(neighbor)
		if neighbor_flow.length_squared() < 0.01:
			continue
		
		# Check where neighbor points to
		var neighbor_points_to = flow_field.world_to_cell(
			flow_field.cell_to_world(neighbor) + neighbor_flow.normalized() * flow_field.cell_size
		)
		
		# Don't allow loops unless backward movement is enabled
		if neighbor_points_to == current_cell and not allow_backward_movement:
			continue
		
		# Valid alternate
		if flow_field.has_method("get_cost_at_cell"):
			var cost = flow_field.get_cost_at_cell(neighbor)
			valid_alternates.append({"cell": neighbor, "cost": cost})
		else:
			# No cost field, return first valid
			return neighbor
	
	# Sort by cost and return best
	if valid_alternates.size() > 0:
		valid_alternates.sort_custom(func(a, b): return a.cost < b.cost)
		return valid_alternates[0].cell
	
	return current_cell
