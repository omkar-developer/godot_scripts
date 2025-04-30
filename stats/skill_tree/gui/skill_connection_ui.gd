class_name SkillConnectionUI
extends Control

@onready var line = $Line2D

var start_node: Control
var end_node: Control
var connection_color := Color.WHITE
var connection_width := 2.0
var is_active := false

# Called when the node enters the scene tree
func _ready():
	line.width = connection_width
	line.default_color = connection_color
	
	# Make sure this connection is behind the nodes
	z_index = -1

# Initialize connection between two nodes
func setup(from_node: Control, to_node: Control) -> void:
	start_node = from_node
	end_node = to_node
	update_connection()

# Update connection color based on whether it's active (parent node is unlocked)
func set_active(active: bool) -> void:
	is_active = active
	line.default_color = connection_color if is_active else Color(connection_color.r, connection_color.g, connection_color.b, 0.3)

# Update connection style
func set_style(color: Color, width: float) -> void:
	connection_color = color
	connection_width = width
	line.width = width
	line.default_color = color if is_active else Color(color.r, color.g, color.b, 0.3)

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

# Called every frame
func _process(_delta: float) -> void:
	# Update connection position if the nodes have moved
	update_connection()
