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
@export_storage var unlocked: bool = false :
	set(value):
		unlocked = value
		if unlocked:
			on_unlocked.emit()

@export_storage var total_parents_level := 0 :
	set(value):
		total_parents_level = value
		if total_parents_level >= required_parent_level:
			unlock_node_internal()

# --- Methods ---

func init_node(stat_owner: Object, inventory: Object) -> void:
	if upgrade:
		upgrade.init_upgrade(stat_owner, inventory)
	else:
		printerr("SkillTreeNode : Upgrade resource not set!")

# Check if the node is currently unlocked.
func is_unlocked() -> bool:
	return unlocked

# Mark the node as unlocked (called by SkillTree).
func unlock_node_internal() -> void:
	unlocked = true

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

# Reset the node's state to its initial values (called by SkillTree reset).
func reset_node_internal():
	unlocked = false
	if upgrade:
		upgrade.reset_upgrades()
