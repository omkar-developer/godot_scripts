class_name SkillTree
extends Resource

signal node_unlocked(node_id)
signal node_upgraded(node_id, new_level)
signal skill_points_changed(new_amount)

# Dictionary mapping node IDs to their SkillTreeNode instances
@export_storage var _nodes: Dictionary = {}
# Dictionary mapping node IDs to arrays of connected node IDs
@export_storage var _connections: Dictionary = {}
# Skill points available for spending (now primarily used for upgrades, not unlocking)
@export var skill_points: int = 0
# Automatically upgrade child _nodes to level 1 when a parent node is unlocked
@export var auto_upgrade_on_unlock: bool = false
# Reference to the inventory for material costs
var _inventory: Object
# Reference to the parent object
var _parent: Object

# MAX, Step
enum UnlockStrategy {
	ALL_PARENTS_TOTAL_LEVEL,
	ANY_PARENT_UNLOCKED,
	EACH_PARENT_MIN_LEVEL
}

@export var unlock_strategy := UnlockStrategy.ALL_PARENTS_TOTAL_LEVEL

# Constructor
func _init(inventory = null):
	_inventory = inventory

func init_tree(inventory: Object = null, parent: Object = null) -> void:
	_inventory = inventory
	_parent = parent

# Add a skill tree node
func add_node(node_id: String, node: SkillTreeNode) -> void:
	if node.upgrade == null:
		printerr("SkillTreeNode '", node.node_name, "': Upgrade resource not set!")
	_nodes[node_id] = node
	_connections[node_id] = []
	node.init_node(_parent, _inventory)
	
	# Connect the upgrade signals to handle automatic unlocking and progression
	node.on_unlocked.connect(_on_node_unlocked.bind(node_id))
	node.upgrade.upgrade_applied.connect(_on_node_upgraded.bind(node_id))
	node.upgrade.max_level_reached.connect(_on_node_max_level.bind(node_id))

# Add a connection between _nodes
func add_connection(from_node_id: String, to_node_id: String) -> void:
	if not _connections.has(from_node_id):
		_connections[from_node_id] = []
	
	if not _connections[from_node_id].has(to_node_id):
		_connections[from_node_id].append(to_node_id)

func get_node_requirement_text(node_id: String) -> String:
	if not _nodes.has(node_id):
		return ""
		
	var node = _nodes[node_id]
	if node.is_unlocked():
		return ""
		
	var parent_nodes = get_parent_nodes(node_id)
	if parent_nodes.is_empty():
		return ""
		
	match unlock_strategy:
		UnlockStrategy.ALL_PARENTS_TOTAL_LEVEL:
			var total_levels = 0
			for parent_id in parent_nodes:
				if _nodes[parent_id].is_unlocked():
					total_levels += _nodes[parent_id].get_current_level()
			return str(total_levels) + "/" + str(node.required_parent_level)
			
		UnlockStrategy.ANY_PARENT_UNLOCKED:
			var highest_level = 0
			for parent_id in parent_nodes:
				if _nodes[parent_id].is_unlocked():
					highest_level = max(highest_level, _nodes[parent_id].get_current_level())
			return str(highest_level) + "/" + str(node.required_parent_level)
			
		UnlockStrategy.EACH_PARENT_MIN_LEVEL:
			var levels_text = ""
			for parent_id in parent_nodes:
				var level = _nodes[parent_id].get_current_level()
				levels_text += str(level) + "/" + str(node.required_parent_level) + " "
			return levels_text.strip_edges()
			
	return ""

func can_unlock_node(node_id: String) -> bool:
	if not _nodes.has(node_id):
		return false

	var node = _nodes[node_id]
	if node.is_unlocked():
		return false

	var parent_nodes = get_parent_nodes(node_id)
	if parent_nodes.is_empty():
		return true

	match unlock_strategy:
		UnlockStrategy.ALL_PARENTS_TOTAL_LEVEL:
			var total_levels = 0
			for parent_id in parent_nodes:
				if not _nodes[parent_id].is_unlocked():
					return false
				total_levels += _nodes[parent_id].get_current_level()
			# Changed condition to check against the required level
			return total_levels >= node.required_parent_level

		UnlockStrategy.ANY_PARENT_UNLOCKED:
			for parent_id in parent_nodes:
				# Also check if parent meets level requirement
				if _nodes[parent_id].is_unlocked() and _nodes[parent_id].get_current_level() >= node.required_parent_level:
					return true
			return false

		UnlockStrategy.EACH_PARENT_MIN_LEVEL:
			for parent_id in parent_nodes:
				if not _nodes[parent_id].is_unlocked() or _nodes[parent_id].get_current_level() < node.required_parent_level:
					return false
			return true

	return false

# Get parent _nodes of a specified node
func get_parent_nodes(node_id: String) -> Array:
	var parents: Array = []
	
	for parent_id in _connections.keys():
		if _connections[parent_id].has(node_id):
			parents.append(parent_id)
	
	return parents

# Get child _nodes of a specified node
func get_child_nodes(node_id: String) -> Array:
	if _connections.has(node_id):
		return _connections[node_id].duplicate()
	return []

# Unlock a node automatically when requirements are met
func unlock_node(node_id: String) -> bool:
	if not can_unlock_node(node_id):
		return false
	
	# Unlock the node
	_nodes[node_id].unlock()
	emit_signal("node_unlocked", node_id)
	
	# Check child _nodes for automatic unlocking
	_check_child_nodes_for_unlock(node_id)
	
	return true

# Check if a node can be upgraded
func can_upgrade_node(node_id: String) -> bool:
	if not _nodes.has(node_id):
		return false
	
	# Must be unlocked first
	if not _nodes[node_id].is_unlocked():
		return false
	
	# Check if we have enough skill points for the upgrade
	var xp_required = _nodes[node_id].upgrade.get_current_xp_required()
	if skill_points < xp_required:
		return false
		
	return _nodes[node_id].upgrade.can_upgrade(skill_points)

# Upgrade a node if possible
func upgrade_node(node_id: String) -> bool:
	if not can_upgrade_node(node_id):
		return false
	
	# Get required XP before we upgrade
	var xp_required = _nodes[node_id].upgrade.get_current_xp_required()
	
	# Attempt to upgrade
	if _nodes[node_id].upgrade.do_upgrade():
		# Consume skill points
		skill_points -= xp_required
		emit_signal("skill_points_changed", skill_points)
		return true
	
	return false

# Add skill points
func add_skill_points(amount: int) -> void:
	skill_points += amount
	emit_signal("skill_points_changed", skill_points)

# Get unlocked _nodes
func get_unlocked_nodes() -> Array:
	var unlocked: Array = []
	for node_id in _nodes.keys():
		if _nodes[node_id].is_unlocked():
			unlocked.append(node_id)
	return unlocked

# Get available _nodes to unlock
func get_available_nodes() -> Array:
	var available: Array = []
	for node_id in _nodes.keys():
		if not _nodes[node_id].is_unlocked() and can_unlock_node(node_id):
			available.append(node_id)
	return available

# Get _nodes that can be currently upgraded with available skill points
func get_upgradable_nodes() -> Array:
	var upgradable: Array = []
	for node_id in _nodes.keys():
		if can_upgrade_node(node_id):
			upgradable.append(node_id)
	return upgradable

# Save the state of the skill tree
func save_state() -> Dictionary:
	var node_states: Dictionary = {}
	for node_id in _nodes.keys():
		node_states[node_id] = _nodes[node_id].save_state()
	
	return {
		"skill_points": skill_points,
		"_nodes": node_states,
		"_connections": _connections
	}

# Load the state of the skill tree
func load_state(data: Dictionary) -> void:
	skill_points = data.get("skill_points", 0)
	
	# Load _nodes
	var node_states = data.get("_nodes", {})
	for node_id in node_states:
		if _nodes.has(node_id):
			_nodes[node_id].load_state(node_states[node_id])
	
	# Load _connections
	var saved_connections = data.get("_connections", {})
	for from_node in saved_connections:
		if _connections.has(from_node):
			_connections[from_node] = saved_connections[from_node].duplicate()

# Check if a specific node is a root node (has no parents)
func is_root_node(node_id: String) -> bool:
	return get_parent_nodes(node_id).is_empty()

# Get all root _nodes
func get_root_nodes() -> Array:
	var roots: Array = []
	for node_id in _nodes.keys():
		if is_root_node(node_id):
			roots.append(node_id)
	return roots

# Check if a node is valid to be displayed/accessed
func is_node_visible(node_id: String) -> bool:
	if not _nodes.has(node_id):
		return false
	
	# Root _nodes are always visible
	if is_root_node(node_id):
		return true
	
	# Node is visible if at least one parent is unlocked
	var parents = get_parent_nodes(node_id)
	for parent_id in parents:
		if _nodes[parent_id].is_unlocked():
			return true
	
	return false

# Reset all _nodes
func reset() -> void:
	for node_id in _nodes:
		_nodes[node_id].reset()

# SIGNAL HANDLERS

# Called when a node is unlocked
func _on_node_unlocked(node_id: String) -> void:
	# Check if child _nodes can now be unlocked
	_check_child_nodes_for_unlock(node_id)

# Called when a node is upgraded
func _on_node_upgraded(new_level: int, _applied_config: UpgradeLevelConfig, node_id: String) -> void:
	emit_signal("node_upgraded", node_id, new_level)
	
	# Check if child _nodes can now be unlocked due to level requirement
	_check_child_nodes_for_unlock(node_id)

# Called when a node reaches max level
func _on_node_max_level(_node_id: String) -> void:
	# Additional logic can be added here if needed
	pass

# Check if any child _nodes can be unlocked
func _check_child_nodes_for_unlock(node_id: String) -> void:
	var child_nodes = get_child_nodes(node_id)
	for child_id in child_nodes:
		if can_unlock_node(child_id):
			unlock_node(child_id)
