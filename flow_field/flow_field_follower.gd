extends Node
class_name FlowFieldFollower
## Simple node component that follows a flow field without collision avoidance
## Just follows the flow direction - no occupancy checking, no pathfinding
## Usage: Add as child to any Node2D

@export var speed: float = 80.0
@export var rotation_speed: float = 6.0
@export var rotate_parent: bool = true
@export var queue_free_on_reached_goal: bool = true

signal reached_goal

var flow_field: FlowFieldManager
var parent_node: Node2D = null

func _ready() -> void:
	# Get parent as Node2D
	parent_node = get_parent() as Node2D
	if parent_node == null:
		push_error("FlowFieldFollower: Parent must be a Node2D!")
		queue_free()
		return
	else:
		# Auto-detect flow_field from parent
		var ffield = parent_node.get("flow_field") as FlowFieldManager
		if ffield and not flow_field:
			flow_field = ffield

func _process(delta: float) -> void:
	if parent_node == null or flow_field == null:
		return

	# Get flow direction at current position
	var flow := flow_field.get_flow_at_position(parent_node.global_position)
	
	# Check if reached goal (flow is zero at goal)
	if flow.length_squared() < 0.01:
		reached_goal.emit()
		if queue_free_on_reached_goal: parent_node.queue_free()
		return
	
	# Move along flow direction
	var move_direction = flow.normalized()
	parent_node.global_position += move_direction * speed * delta
	
	# Smooth rotation toward movement direction
	if rotate_parent:
		var target_angle = move_direction.angle()
		parent_node.rotation = lerp_angle(parent_node.rotation, target_angle, rotation_speed * delta)
