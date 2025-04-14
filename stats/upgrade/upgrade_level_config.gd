# UpgradeLevelConfig.gd
extends Resource
class_name UpgradeLevelConfig

@export var xp_required: int = 100
@export var modifiers: StatModifierSet  # Assumes you have a StatModifierSet class.
@export var required_materials: Dictionary = {}  # Example: { "wood": 5, "ore": 3 }
