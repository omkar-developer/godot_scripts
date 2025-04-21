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

## Converts the UpgradeLevelConfig to a dictionary.
func to_dict() -> Dictionary:
	var dict = {}
	dict["xp_required"] = xp_required
	dict["modifiers"] = modifiers.to_dict()
	dict["required_materials"] = required_materials.duplicate()
	return dict

## Populates the UpgradeLevelConfig from a dictionary.
func from_dict(dict: Dictionary) -> void:
	xp_required = dict["xp_required"]
	modifiers.from_dict(dict["modifiers"])
	required_materials.clear()
	for material in dict["required_materials"]:
		var quantity = dict["required_materials"][material]
		required_materials[material] = quantity