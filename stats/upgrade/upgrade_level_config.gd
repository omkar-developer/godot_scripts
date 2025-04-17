## Represents the configuration for an upgrade level in a game.
## Contains information about the XP required to reach this level,
## modifiers applied when reaching this level, and materials needed.

extends Resource
class_name UpgradeLevelConfig

## The amount of XP required to achieve this upgrade level.[br]
@export var xp_required: int = 100

## A set of stat modifiers that are applied when the player reaches this upgrade level.
@export var modifiers: StatModifierSet

## A dictionary containing materials and their quantities required for this upgrade level.[br]
@export var required_materials: Dictionary[StringName, int] = {}  # Example: { "wood": 5, "ore": 3 }