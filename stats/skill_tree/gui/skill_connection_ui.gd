class_name SkillConnectionUI
extends Control

@onready var line = $Line2D

var start_node: Control
var end_node: Control
var connection_color := Color.WHITE
var active_color := Color(0.2, 0.8, 0.2)
var is_active := false

# Called when the node enters the scene tree
func _ready():
	z_index = -1

# Initialize connection between two nodes
func setup(from_node: Control, to_node: Control) -> void:
	start_node = from_node
	end_node = to_node
	update_connection()

func _set_style() -> void:
	# Set the connection color based on whether it's active
	connection_color = active_color if is_active else connection_color
	line.default_color = connection_color

# Update connection color based on whether it's active (parent node is unlocked)
func set_active(active: bool) -> void:
	is_active = active
	_set_style()

# Update the connection position and shape
func update_connection() -> void:
	if !is_instance_valid(start_node) or !is_instance_valid(end_node):
		return
	
	# Get center points of both nodes
	var start_center = start_node.global_position + (start_node.size / 2)
	var end_center = end_node.global_position + (end_node.size / 2)
	
	# Convert to local coordinates
	var start_local = line.to_local(start_center)
	var end_local = line.to_local(end_center)
	
	# Update the line points
	line.clear_points()
	line.add_point(start_local)
	line.add_point(end_local)
