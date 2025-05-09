class_name SkillNodeUI
extends Control

signal on_upgrade(level)
signal on_unlocked(node_ui)
signal on_node_clicked(node_ui)

@export var node_id: StringName
@export var skill_node: SkillTreeNode
@export var children_nodes: Array[SkillNodeUI] = []

# Style customization
@export_category("Visual Settings")
@export var locked_color: Color = Color(0.39, 0.39, 0.39, 1.0)      # Node is locked
@export var unlocked_color: Color = Color(0.7, 0.7, 0.7, 1.0)       # Node is unlocked but level 0
@export var invested_color: Color = Color.WHITE                     # Node has points invested (level 1+)
@export var hover_color: Color = Color(1.2, 1.2, 1.2, 1.0)          # Hover effect
@export var selected_color: Color = Color(1.4, 1.4, 0.6, 1.0)       # Selection highlight
@export var hover_scale: Vector2 = Vector2(1.1, 1.1)

# Visual components visibility
@export var show_lock_icon: bool = true                             # Show lock icon when locked
@export var hide_level_when_locked: bool = true                     # Hide level label when locked

# Animation settings
@export_category("Animation Settings")
@export var press_animation_duration: float = 0.15
@export var hover_animation_duration: float = 0.2
@export var level_up_animation_duration: float = 0.5
@export var pulse_strength: float = 1.5  # For level-up effect

# Cached references
@onready var icon = %Icon
@onready var level_label = %LevelLabel
@onready var background = %Background
@onready var lock_icon = %LockIcon if has_node("%LockIcon") else null

# State variables
var is_hovered: bool = false
var is_selected: bool = false
var node_state: int = NodeState.LOCKED  # Track the visual state
var normal_color: Color = locked_color  # Changes based on state

# Animation tweens
var hover_tween: Tween
var press_tween: Tween
var level_up_tween: Tween
var current_level: int = 0

# Node state enum
enum NodeState {
	LOCKED,     # Node is locked, can't be interacted with
	UNLOCKED,   # Node is unlocked but at level 0
	INVESTED    # Node has at least 1 point invested
}

func _ready() -> void:
	# Set initial state
	if skill_node:
		# Connect signals from the skill node
		if not skill_node.on_unlocked.is_connected(_on_node_unlocked):
			skill_node.on_unlocked.connect(_on_node_unlocked)
		
		# Initialize visual state based on node's current state
		refresh_node_state()
		
		# Update the level label
		current_level = skill_node.get_current_level()
		_update_level_label()
	else:
		refresh_node_state()
		printerr("SkillNodeUI: No skill_node assigned!")

# Determine the current state of the node
func get_node_state() -> int:
	if not is_instance_valid(skill_node):
		return NodeState.LOCKED
	if not skill_node.is_unlocked():
		return NodeState.LOCKED
	elif skill_node.get_current_level() == 0:
		return NodeState.UNLOCKED
	else:
		return NodeState.INVESTED

# Updates node's visual state when unlocked
func _on_node_unlocked() -> void:
	# Update state
	node_state = NodeState.UNLOCKED
	normal_color = unlocked_color
	
	# Update visuals
	icon.self_modulate = normal_color
	
	# Handle lock icon if present
	if lock_icon:
		lock_icon.visible = false
	
	# Show level label if it was hidden
	if hide_level_when_locked:
		level_label.visible = true
	
	# Play unlock animation
	_play_unlock_animation()
	
	# Emit signal
	on_unlocked.emit(self)

# Play unlock animation
func _play_unlock_animation() -> void:
	if level_up_tween:
		level_up_tween.kill()
	
	level_up_tween = create_tween().set_parallel()
	
	# Animate icon
	level_up_tween.tween_property(icon, "self_modulate", Color(2, 2, 2, 1), level_up_animation_duration * 0.3)
	level_up_tween.chain().tween_property(icon, "self_modulate", normal_color, level_up_animation_duration * 0.7)
	
	# Scale animation
	level_up_tween.tween_property(self, "scale", Vector2(1.3, 1.3), level_up_animation_duration * 0.3)
	level_up_tween.chain().tween_property(self, "scale", Vector2.ONE, level_up_animation_duration * 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Rotate slightly for effect
	level_up_tween.tween_property(self, "rotation_degrees", 10, level_up_animation_duration * 0.15)
	level_up_tween.chain().tween_property(self, "rotation_degrees", -10, level_up_animation_duration * 0.3)
	level_up_tween.chain().tween_property(self, "rotation_degrees", 0, level_up_animation_duration * 0.55).set_trans(Tween.TRANS_ELASTIC)

# Update visual state when investing in the node (going from level 0 to 1+)
func _invested() -> void:
	# Update state
	node_state = NodeState.INVESTED
	normal_color = invested_color
	
	# Update visuals
	icon.self_modulate = normal_color

# Handle upgrade logic
func upgrade() -> bool:
	if not skill_node:
		return false
	
	if not skill_node.is_unlocked():
		return false

	var old_level = skill_node.get_current_level()
	if skill_node.upgrade_level():
		var new_level = skill_node.get_current_level()
		_update_level_label()
		
		# Check if we went from level 0 to level 1
		if old_level == 0 and new_level == 1:
			_invested()
		
		on_upgrade.emit(new_level)
		
		# Play animation if level actually changed
		if new_level > old_level:
			_play_level_up_animation()
		
		return true
	
	return false

# Play level up animation
func _play_level_up_animation() -> void:
	if level_up_tween:
		level_up_tween.kill()
	
	level_up_tween = create_tween().set_parallel()
	
	# Animate the level label
	level_up_tween.tween_property(level_label, "modulate", Color(pulse_strength, pulse_strength, 0.5, 1), level_up_animation_duration * 0.3)
	level_up_tween.chain().tween_property(level_label, "modulate", Color.WHITE, level_up_animation_duration * 0.7)
	
	# Scale the label
	level_up_tween.tween_property(level_label, "scale", Vector2(1.5, 1.5), level_up_animation_duration * 0.3)
	level_up_tween.chain().tween_property(level_label, "scale", Vector2.ONE, level_up_animation_duration * 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Make the whole node pulse
	level_up_tween.tween_property(self, "scale", Vector2(1.2, 1.2), level_up_animation_duration * 0.3)
	level_up_tween.chain().tween_property(self, "scale", Vector2.ONE, level_up_animation_duration * 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Add a subtle icon color pulse
	level_up_tween.tween_property(icon, "self_modulate", Color(1.5, 1.5, 0.5, 1), level_up_animation_duration * 0.3)
	level_up_tween.chain().tween_property(icon, "self_modulate", normal_color, level_up_animation_duration * 0.7)

# Update the level label display
func _update_level_label() -> void:
	if skill_node:
		level_label.text = "L" + str(skill_node.get_current_level())
		
		# Optionally hide level when locked
		if hide_level_when_locked:
			level_label.visible = skill_node.is_unlocked()

# Highlight the node (for hover or selection)
func _highlighted(highlight: bool = true) -> void:
	if hover_tween:
		hover_tween.kill()
	
	hover_tween = create_tween().set_parallel()
	
	if highlight:
		# Target color based on selection state
		var target_color = selected_color if is_selected else hover_color
		
		# Scale up animation
		hover_tween.tween_property(self, "scale", hover_scale, hover_animation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# Color animation
		hover_tween.tween_property(icon, "self_modulate", target_color, hover_animation_duration).set_trans(Tween.TRANS_CUBIC)
	else:
		# Target color based on selection and state
		var target_color = selected_color if is_selected else normal_color
		
		# Scale down animation
		hover_tween.tween_property(self, "scale", Vector2.ONE, hover_animation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# Color animation
		hover_tween.tween_property(icon, "self_modulate", target_color, hover_animation_duration).set_trans(Tween.TRANS_CUBIC)

# Set the selected state
func set_selected(selected: bool = true) -> void:
	is_selected = selected
	_highlighted(is_hovered)

# Input Handling
func _on_mouse_entered() -> void:
	if not skill_node:
		return
	if not skill_node.is_unlocked():
		return
	is_hovered = true
	_highlighted(true)

func _on_mouse_exited() -> void:
	is_hovered = false
	_highlighted(false)

func _on_gui_input(event: InputEvent) -> void:
	if not skill_node:
		return
	if not skill_node.is_unlocked():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Emit signal so parent can handle selection
		on_node_clicked.emit(self)
		
		# Play press animation
		_play_press_animation()
		
		# Try to upgrade this node
		upgrade()

# Play button press animation
func _play_press_animation() -> void:
	if press_tween:
		press_tween.kill()
	
	press_tween = create_tween().set_parallel()
	
	# Scale down for press effect
	press_tween.tween_property(self, "scale", Vector2(0.9, 0.9), press_animation_duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	press_tween.chain().tween_property(self, "scale", hover_scale if is_hovered else Vector2.ONE, press_animation_duration * 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Slight rotation for tactile feel
	press_tween.tween_property(self, "rotation_degrees", 5, press_animation_duration * 0.25)
	press_tween.chain().tween_property(self, "rotation_degrees", -5, press_animation_duration * 0.25)
	press_tween.chain().tween_property(self, "rotation_degrees", 0, press_animation_duration * 0.5).set_trans(Tween.TRANS_ELASTIC)
	
	# Slightly darken on press
	var pressed_color = icon.self_modulate.darkened(0.2)
	press_tween.tween_property(icon, "self_modulate", pressed_color, press_animation_duration * 0.5)
	press_tween.chain().tween_property(icon, "self_modulate", selected_color if is_selected else (hover_color if is_hovered else normal_color), press_animation_duration * 0.5)

func _on_focus_entered() -> void:
	is_hovered = true
	_highlighted(true)

func _on_focus_exited() -> void:
	is_hovered = false
	_highlighted(false)

# Public methods for external control

func init_upgrade(stat_owner: Object, inventory: Object = null, tree: SkillTree = null) -> void:
	if skill_node:
		skill_node.init_node(stat_owner, inventory, tree)

# Refresh node state based on the current skill node state
func refresh_node_state() -> void:
	# Determine the current state
	node_state = get_node_state()
	
	# Set the appropriate color based on state
	match node_state:
		NodeState.LOCKED:
			normal_color = locked_color
			if lock_icon:
				lock_icon.visible = show_lock_icon
			if hide_level_when_locked:
				level_label.visible = false
		NodeState.UNLOCKED:
			normal_color = unlocked_color
			if lock_icon:
				lock_icon.visible = false
			if hide_level_when_locked:
				level_label.visible = true
		NodeState.INVESTED:
			normal_color = invested_color
			if lock_icon:
				lock_icon.visible = false
			if hide_level_when_locked:
				level_label.visible = true
	
	# Apply the color
	icon.self_modulate = normal_color

# Refresh the node's visual state (call after skill_node changes)
func refresh_node() -> void:
	if skill_node:
		refresh_node_state()
		_update_level_label()
		
		# Apply current hover/selection state
		if is_hovered or is_selected:
			_highlighted(true)

# Unlock the node
func unlock() -> void:
	if skill_node:
		skill_node.unlock()
