class_name SkillConnectionUI
extends Control

@onready var line := %Line2D
@export var show_requirements: bool = true
@export var line_width: float = 2
@onready var requirement_label:= %Requirements
@export var label_offset: Vector2 = Vector2(-32, -16)
@export var connection_color := Color.WHITE
@export var active_color := Color(0.2, 0.8, 0.2)
@export var animation_duration: float = 0.5
@export var glow_strength: float = 1.5

var activation_tween: Tween

var start_node: Control
var end_node: Control
var is_active := false

# Called when the node enters the scene tree
func _ready():
	z_index = -1

# Initialize connection between two nodes
func setup(from_node: Control, to_node: Control) -> void:
	start_node = from_node
	end_node = to_node
	update_connection()
	_set_style()

func update_requirement_text(skill_tree: SkillTree) -> void:
	if not show_requirements or not requirement_label or not end_node:
		return
		
	var req_text = skill_tree.get_node_requirement_text(end_node.node_id)
	requirement_label.text = req_text

func _play_activation_animation() -> void:
	if activation_tween:
		activation_tween.kill()
	
	activation_tween = create_tween().set_parallel()
	
	# Animate line color
	var glow_color = active_color.lightened(0.5)
	activation_tween.tween_property(line, "default_color", glow_color, animation_duration * 0.3)
	activation_tween.chain().tween_property(line, "default_color", active_color, animation_duration * 0.7)
	
	# Animate line width
	var original_width = line.width
	activation_tween.tween_property(line, "width", original_width * glow_strength, animation_duration * 0.3)
	activation_tween.chain().tween_property(line, "width", original_width, animation_duration * 0.7)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Optional: Animate modulate for overall glow effect
	activation_tween.tween_property(line, "modulate", Color(1.2, 1.2, 1.2, 1), animation_duration * 0.3)
	activation_tween.chain().tween_property(line, "modulate", Color.WHITE, animation_duration * 0.7)

func _set_style() -> void:
	if is_active:
		_play_activation_animation()
	else:
		line.width = line_width
		line.modulate = Color.WHITE
		line.default_color = active_color if is_active else connection_color

# Update connection color based on whether it's active (parent node is unlocked)
func set_active(active: bool) -> void:
	if active == is_active:
		return
	is_active = active
	_set_style()

func get_middle_point() -> Vector2:
	if line.get_point_count() < 2:
		return line.get_point_position(0)
	if line.get_point_count() % 2 == 0:
		return (line.get_point_position((line.get_point_count() / 2) - 1) + line.get_point_position(line.get_point_count() / 2 )) / 2
	else:
		return line.get_point_position(line.get_point_count() / 2)

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

	# Position the label at the middle of the connection line
	if line:
		requirement_label.position = get_middle_point() + label_offset
