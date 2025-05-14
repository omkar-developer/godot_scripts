class_name SkillTreeUI
extends Control

# Emitted when a node is clicked
signal node_clicked(node_ui)
# Emitted when a node is unlocked
signal node_unlocked(node_id)
# Emitted when a node is upgraded
signal node_upgraded(node_id, new_level)
# Emitted when connections are created
signal connections_created

# Path to the skill connection scene
@export var skill_connection_scene: PackedScene
# Whether to create connections in the tree from node children relationships
@export var create_connections_from_node_children: bool = true

@export var auto_unlock_root_nodes: bool = true

@export var stats_owner: Node = null

@export var inventory: Node = null

# Reference to the actual skill tree data
@export var skill_tree: SkillTree

# Dictionaries to store and track UI elements
var node_ui_elements: Dictionary = {}  # Maps node_id to SkillNodeUI
var connections: Array[SkillConnectionUI] = []  # Stores all connection objects

# Connection visual settings
@export_group("Connection Settings")
@export var set_connection_color: bool = false
@export var color_normal: Color = Color(0.5, 0.5, 0.5, 0.7)
@export var color_active: Color = Color(0.2, 0.8, 0.2, 1.0)
@export var line_width: float = 2.0

func _enter_tree() -> void:
	if stats_owner == null:
		stats_owner = get_parent()
	if skill_tree == null:
		skill_tree = SkillTree.new()
	skill_tree.init_tree(inventory, stats_owner)	

# Called when the node enters the scene tree for the first time
func _ready():
	_find_skill_node_ui_children()
	initialize_skill_tree(skill_tree)

# Initialize with a SkillTree instance
func initialize_skill_tree(tree: SkillTree) -> void:
	skill_tree = tree
	
	# Connect signals from the skill tree
	skill_tree.node_unlocked.connect(_on_skill_tree_node_unlocked)
	skill_tree.node_upgraded.connect(_on_skill_tree_node_upgraded)
	skill_tree.skill_points_changed.connect(_on_skill_points_changed)
	
	# Find all SkillNodeUI children and initialize them
	_initialize_node_uis()
	
	# Create connections between nodes
	_create_connections()
	
	# Unlock root nodes
	if auto_unlock_root_nodes:
		for root_node_id in skill_tree.get_root_nodes():
			skill_tree.unlock_node(root_node_id)
	
	# Refresh UI state
	refresh_all()

# Find all SkillNodeUI children in the scene
func _find_skill_node_ui_children() -> void:
	node_ui_elements.clear()
	# Recursively find all SkillNodeUI objects
	_find_skill_node_ui_recursive(self)

# Recursive helper function to find all SkillNodeUI children
func _find_skill_node_ui_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is SkillNodeUI:
			var node_ui := child as SkillNodeUI
			# Auto-generate node_id if empty
			if node_ui.node_id.is_empty():
				node_ui.node_id = str(child.get_path()).replace("/", "_")
			
			if node_ui.skill_node != null and not skill_tree._nodes.has(node_ui.node_id):
				skill_tree.add_node(node_ui.node_id, node_ui.skill_node)
			
				node_ui_elements[node_ui.node_id] = node_ui
				# Connect the node UI signals
				node_ui.on_node_clicked.connect(_on_node_ui_clicked)
				node_ui.on_unlocked.connect(_on_node_ui_unlocked)
				node_ui.on_upgrade.connect(_on_node_ui_upgraded)
		
		# Recursively check children
		if child.get_child_count() > 0:
			_find_skill_node_ui_recursive(child)

# Initialize all SkillNodeUI elements
func _initialize_node_uis() -> void:
	for node_id in node_ui_elements:
		var node_ui = node_ui_elements[node_id]
		node_ui.init_upgrade(stats_owner, inventory, skill_tree)
		node_ui.refresh_node()

# Create connections between nodes based on the skill tree
func _create_connections() -> void:
	# Clear any runtime-created connections (but not preexisting scene connections)
	for connection in connections:
		if connection and is_instance_valid(connection) and !connection.is_in_group("preexisting_connection"):
			connection.queue_free()
	connections.clear()
	
	# Dictionary to track connections we already have
	var existing_connections := {}
	
	# First: Find all preexisting SkillConnectionUI children in the scene
	_find_connections_recursive(self, existing_connections)
	
	# Second: Create connections from SkillTree data
	_create_connections_from_skill_tree(existing_connections)
	
	# Third: Create connections from SkillNodeUI children_nodes arrays
	_create_connections_from_node_ui_children(existing_connections)
	
	# Emit signal that connections have been created
	emit_signal("connections_created")

# Find preexisting connections in the scene
func _find_connections_recursive(node: Node, existing_connections: Dictionary) -> void:
	for child in node.get_children():
		if child is SkillConnectionUI:
			var connection := child as SkillConnectionUI
			if set_connection_color:
				connection.setup_style(color_normal, color_active, line_width)
			if connection.start_node and connection.end_node:
				var from_node_ui = connection.start_node as SkillNodeUI
				var to_node_ui = connection.end_node as SkillNodeUI
				
				if from_node_ui and to_node_ui and from_node_ui.node_id and to_node_ui.node_id:
					# Add to existing connections dictionary
					var connection_key = from_node_ui.node_id + "_" + to_node_ui.node_id
					existing_connections[connection_key] = connection
					
					# Mark as preexisting connection
					connection.add_to_group("preexisting_connection")
					
					 # Add connection to skill tree data structure if it doesn't exist
					if skill_tree:
						if !skill_tree._connections.has(from_node_ui.node_id):
							skill_tree._connections[from_node_ui.node_id] = []
						if !skill_tree._connections[from_node_ui.node_id].has(to_node_ui.node_id):
							skill_tree.add_connection(from_node_ui.node_id, to_node_ui.node_id)
					
					# Update connection style - check both nodes are unlocked
					if skill_tree and skill_tree._nodes.has(from_node_ui.node_id) and skill_tree._nodes.has(to_node_ui.node_id):
						var is_active = skill_tree._nodes[from_node_ui.node_id].is_unlocked() and skill_tree._nodes[to_node_ui.node_id].is_unlocked()
						connection.set_active(is_active)
					
					connections.append(connection)
					
		# Recursively check children
		if child.get_child_count() > 0:
			_find_connections_recursive(child, existing_connections)

# Create connections from SkillTree data
func _create_connections_from_skill_tree(existing_connections: Dictionary) -> void:
	if !skill_tree:
		return
		
	for from_node_id in skill_tree._connections:
		if not node_ui_elements.has(from_node_id):
			continue
			
		var from_node_ui = node_ui_elements[from_node_id]
		
		for to_node_id in skill_tree._connections[from_node_id]:
			if not node_ui_elements.has(to_node_id):
				continue
				
			var to_node_ui = node_ui_elements[to_node_id]
			
			# Skip if this connection already exists
			var connection_key = from_node_id + "_" + to_node_id
			if existing_connections.has(connection_key):
				continue
				
			# Create the connection
			var connection = skill_connection_scene.instantiate() as SkillConnectionUI
			if set_connection_color:
				connection.setup_style(color_normal, color_active, line_width)
			add_child(connection)
			connection.setup(from_node_ui, to_node_ui)
			
			# Set connection style based on whether parent node is unlocked
			var is_active = skill_tree._nodes[from_node_id].is_unlocked()			
			connection.set_active(is_active)
			
			# Add to tracking
			existing_connections[connection_key] = connection
			connections.append(connection)

# Create connections from SkillNodeUI children_nodes arrays
func _create_connections_from_node_ui_children(existing_connections: Dictionary) -> void:
	if !create_connections_from_node_children:
		return
		
	for from_node_id in node_ui_elements:
		var from_node_ui = node_ui_elements[from_node_id] as SkillNodeUI
		
		# Check for children_nodes array
		if from_node_ui.has_method("get_children_nodes") or from_node_ui.get("children_nodes") != null:
			var children_nodes = []
			
			# Try to get children_nodes using either method or property
			if from_node_ui.has_method("get_children_nodes"):
				children_nodes = from_node_ui.get_children_nodes()
			else:
				children_nodes = from_node_ui.get("children_nodes")
			
			# Create connections to children nodes
			for child_node_ui in children_nodes:
				if child_node_ui is SkillNodeUI and child_node_ui.node_id:
					var to_node_id = child_node_ui.node_id
					
					# Skip if this connection already exists
					var connection_key = from_node_id + "_" + to_node_id
					if existing_connections.has(connection_key):
						continue
					
					# Create the connection
					var connection = skill_connection_scene.instantiate() as SkillConnectionUI
					if set_connection_color:
						connection.setup_style(color_normal, color_active, line_width)
					add_child(connection)
					connection.setup(from_node_ui, child_node_ui)
					
					# Set connection style
					var is_active = false
					if skill_tree and skill_tree._nodes.has(from_node_id):
						is_active = skill_tree._nodes[from_node_id].is_unlocked()					
					connection.set_active(is_active)
					
					# Add to tracking
					existing_connections[connection_key] = connection
					connections.append(connection)
					
					# Also add connection to the skill tree's data if it doesn't exist
					if skill_tree and !skill_tree._connections.has(from_node_id):
						skill_tree._connections[from_node_id] = []
					
					if skill_tree and !skill_tree._connections[from_node_id].has(to_node_id):
						skill_tree.add_connection(from_node_id, to_node_id)

# Refresh the entire skill tree UI
func refresh_all() -> void:
	for node_id in node_ui_elements:
		node_ui_elements[node_id].refresh_node()
	
	# Update connection states
	_update_connection_states()

# Update connection visuals based on node states
func _update_connection_states(node_id := "") -> void:
	for connection in connections:
		if connection.start_node is SkillNodeUI and connection.end_node is SkillNodeUI:
			if node_id != "" and node_id != connection.start_node.node_id:
				continue
			var start_node_ui = connection.start_node as SkillNodeUI
			var end_node_ui = connection.end_node as SkillNodeUI
			var is_active = start_node_ui.skill_node.is_unlocked() and end_node_ui.skill_node.is_unlocked()
			connection.set_active(is_active)
			connection.update_requirement_text(skill_tree)

# SIGNAL HANDLERS

# Node UI was clicked
func _on_node_ui_clicked(node_ui: SkillNodeUI) -> void:
	emit_signal("node_clicked", node_ui)

# Node UI was unlocked
func _on_node_ui_unlocked(_node_ui: SkillNodeUI) -> void:
	# Update connections
	_update_connection_states()

# Node UI was upgraded
func _on_node_ui_upgraded(_node_ui: SkillNodeUI, _level: int) -> void:
	# Check if any connections need updating
	_update_connection_states()

# Skill tree node was unlocked
func _on_skill_tree_node_unlocked(node_id: String) -> void:
	if node_ui_elements.has(node_id):
		node_ui_elements[node_id].refresh_node()
	
	# Update connections
	_update_connection_states()
	
	emit_signal("node_unlocked", node_id)

# Skill tree node was upgraded
func _on_skill_tree_node_upgraded(node_id: String, new_level: int) -> void:
	if node_ui_elements.has(node_id):
		node_ui_elements[node_id].refresh_node()
	_update_connection_states(node_id)	
	emit_signal("node_upgraded", node_id, new_level)

# Skill points changed
func _on_skill_points_changed(_new_amount: int) -> void:
	# Refresh all nodes to update their appearance based on whether they can be upgraded
	refresh_all()

# Try to upgrade a node
func try_upgrade_node(node_id: String) -> bool:
	if node_ui_elements.has(node_id):
		return node_ui_elements[node_id].try_upgrade()
	return false

# Try to unlock a node
func try_unlock_node(node_id: String) -> bool:
	if skill_tree and skill_tree.can_unlock_node(node_id):
		return skill_tree.unlock_node(node_id)
	return false
