# Represents the data, state, and configuration for a single node in the skill tree.
class_name SkillTreeNode
extends Resource

# Signal when node is unlocked
signal on_unlocked

# The Upgrade resource instance defining levels, costs, and effects for this node.
# Assign the configured Upgrade object (as RefCounted/Object) here, or create it in code.
# IMPORTANT: If Upgrade holds runtime state, it should NOT be a Resource itself.
@export var upgrade: Upgrade = null

@export var auto_upgrade_to_level_1: bool = false

# Required level the parent(s) must reach before this node can be unlocked.
@export var required_parent_level: int = 1 

# --- Runtime State ---
var steps_reached := 0

var unlocked: bool = false :
	set(value):
		unlocked = value
		if unlocked:
			on_unlocked.emit()

var total_parents_level := 0 :
	set(value):
		total_parents_level = value
		if total_parents_level >= required_parent_level:
			unlock()

var skill_tree: SkillTree
# --- Methods ---

func init_node(stat_owner: Object, inventory: Object = null, _skill_tree: SkillTree = null) -> void:
	self.skill_tree = _skill_tree
	if upgrade:
		upgrade.init_upgrade(stat_owner, inventory)
		upgrade.step_reached.connect(_step_reached)
		if auto_upgrade_to_level_1 and upgrade.get_current_level() == 0:
			upgrade_level(true)
	else:
		printerr("SkillTreeNode : Upgrade resource not set!")

func _step_reached(_step_level: int) -> void:
	steps_reached += 1

# Check if the node is currently unlocked.
func is_unlocked() -> bool:
	return unlocked

# Mark the node as unlocked (called by SkillTree).
func unlock() -> void:
	unlocked = true

# Attempt to upgrade the node's level.
func upgrade_level(ignore_cost: bool = false) -> bool:
	if not is_instance_valid(upgrade):
		return false
	if skill_tree and not ignore_cost:
		if skill_tree.skill_points < upgrade.get_current_xp_required():
			return false
	if upgrade.level_up():
		return true
	return false

# Get the cost in XP points required for the next level (or level 1 if locked).
func get_next_level_xp_cost() -> int:
	if upgrade:
		return upgrade.get_current_xp_required()
	printerr("SkillTreeNode : Upgrade resource not set!")
	return 0 # Indicate an error or impossibly high cost

# Get the current level of the node's upgrade track.
func get_current_level() -> int:
	if upgrade:
		return upgrade.get_current_level()
	return 0

func is_max_level() -> bool:
	if upgrade:
		return upgrade.is_max_level()
	return false

# Reset the node's state to its initial values (called by SkillTree reset).
func reset_node_internal():
	unlocked = false
	if upgrade:
		upgrade.reset_upgrades()

func to_dict() -> Dictionary:
	return {
		"upgrade": {
			"class_name": upgrade.get_script().get_global_name() if upgrade else "",
			"data": upgrade.to_dict() if upgrade else {}
		},
		"auto_upgrade_to_level_1": auto_upgrade_to_level_1,
		"required_parent_level": required_parent_level,
		"steps_reached": steps_reached,
		"unlocked": unlocked,
		"total_parents_level": total_parents_level
	}

func from_dict(data: Dictionary, stat_owner: Object = null, inventory: Object = null, _skill_tree: SkillTree = null) -> void:
	if data == null:
		return
		
	auto_upgrade_to_level_1 = data.get("auto_upgrade_to_level_1", false)
	required_parent_level = data.get("required_parent_level", 1)
	steps_reached = data.get("steps_reached", 0)
	unlocked = data.get("unlocked", false)
	total_parents_level = data.get("total_parents_level", 0)
	
	var upgrade_data = data.get("upgrade", {})
	if upgrade_data.has("class_name") and upgrade_data["class_name"] != "":
		upgrade = _instantiate_class(upgrade_data["class_name"])
		if upgrade:
			upgrade.from_dict(upgrade_data["data"])
	
	init_node(stat_owner, inventory, _skill_tree)

func _instantiate_class(class_type: String) -> Object:
	var global_classes = ProjectSettings.get_global_class_list()
	
	# Find the class in the global class list
	for gc in global_classes:
		if gc["class"] == class_type:
			# Load the script and instantiate it
			var script = load(gc["path"])
			if script:
				return script.new()
	
	push_warning("Unknown class type: %s, defaulting to null." % class_type)
	return null
