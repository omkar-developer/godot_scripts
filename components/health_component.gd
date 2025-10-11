class_name HealthComponent
extends BaseHealthComponent

## Simple health component using direct float values with no dependencies.[br]
##[br]
## This component stores health, shield, and resistance data as simple float properties.[br]
## Ideal for simple enemies, projectiles, or objects that don't need stat system integration.[br]
## All calculations and logic are handled by the base class.

## Current health value
var current_health: float = 100.0

## Maximum health value
var max_health: float = 100.0

## Current shield value
var current_shield: float = 0.0

## Maximum shield value
var max_shield: float = 0.0

## Flat damage reduction (armor)
var damage_reduction: float = 0.0

## Damage multiplier (0.5 = 50% damage taken, 1.0 = 100%)
var damage_multiplier: float = 1.0

## Resistance by damage type {damage_type: resistance_value}
var resistances: Dictionary = {}  # {int: float}

## Constructor.[br]
## [param _owner]: The Object that owns this component.[br]
## [param _max_health]: Maximum health value.[br]
## [param _iframe_duration]: Seconds of invulnerability after taking damage (0.0 = disabled).[br]
## [param _shield_enabled]: Whether to process shield damage.[br]
## [param _max_shield]: Maximum shield value (if shield enabled).[br]
## [param _max_damage_per_hit]: Maximum damage allowed per hit (0.0 = no limit).[br]
## [param _prevent_death_once]: Whether to prevent death once at 1 HP.[br]
## [param _immune_damage_types]: Array of damage types to completely ignore.
func _init(
	_owner: Object,
	_max_health: float = 100.0,
	_iframe_duration: float = 0.0,
	_shield_enabled: bool = false,
	_max_shield: float = 0.0,
	_max_damage_per_hit: float = 0.0,
	_prevent_death_once: bool = false,
	_immune_damage_types: Array[int] = []
) -> void:
	super._init(_owner, _iframe_duration, _shield_enabled, _max_damage_per_hit, _prevent_death_once, _immune_damage_types)
	
	max_health = _max_health
	current_health = _max_health
	max_shield = _max_shield
	current_shield = _max_shield if _shield_enabled else 0.0


## Get current health value (override).[br]
## [return]: Current health.
func get_health() -> float:
	return current_health


## Get maximum health value (override).[br]
## [return]: Max health.
func get_max_health() -> float:
	return max_health


## Get current shield value (override).[br]
## [return]: Current shield.
func get_shield() -> float:
	return current_shield


## Get maximum shield value (override).[br]
## [return]: Max shield.
func get_max_shield() -> float:
	return max_shield


## Internal: Modify health by delta amount (override).[br]
## [param delta]: Amount to change health by (positive = heal, negative = damage).
func _modify_health(delta: float) -> void:
	current_health = clampf(current_health + delta, 0.0, max_health)


## Internal: Set health to specific value (override).[br]
## [param value]: New health value.
func _set_health(value: float) -> void:
	current_health = clampf(value, 0.0, max_health)


## Internal: Modify shield by delta amount (override).[br]
## [param delta]: Amount to change shield by (positive = restore, negative = damage).
func _modify_shield(delta: float) -> void:
	current_shield = clampf(current_shield + delta, 0.0, max_shield)


## Internal: Get resistance value for damage type (override).[br]
## [param damage_type]: The damage type to get resistance for.[br]
## [return]: Resistance value (0.0 to 1.0).
func _get_resistance(damage_type: int) -> float:
	return resistances.get(damage_type, 0.0)


## Internal: Get flat damage reduction value (override).[br]
## [return]: Flat damage reduction amount.
func _get_damage_reduction() -> float:
	return damage_reduction


## Internal: Get damage multiplier (override).[br]
## [return]: Damage multiplier (1.0 = 100%, 0.5 = 50% damage taken).
func _get_damage_multiplier() -> float:
	return damage_multiplier


## Set a resistance value for a specific damage type.[br]
## [param damage_type]: The damage type identifier.[br]
## [param resistance]: Resistance value (0.0 = no resist, 1.0 = immune).
func set_resistance(damage_type: int, resistance: float) -> void:
	resistances[damage_type] = clampf(resistance, 0.0, 1.0)


## Get resistance for a damage type.[br]
## [param damage_type]: The damage type identifier.[br]
## [return]: Resistance value (0.0 if not set).
func get_resistance(damage_type: int) -> float:
	return resistances.get(damage_type, 0.0)


## Remove resistance for a damage type.[br]
## [param damage_type]: The damage type identifier.
func remove_resistance(damage_type: int) -> void:
	resistances.erase(damage_type)


## Set max health and optionally adjust current health.[br]
## [param new_max]: New maximum health value.[br]
## [param adjust_current]: If true, scale current health proportionally.
func set_max_health(new_max: float, adjust_current: bool = false) -> void:
	if adjust_current and max_health > 0.0:
		var ratio := current_health / max_health
		max_health = new_max
		current_health = new_max * ratio
	else:
		max_health = new_max
		current_health = minf(current_health, max_health)


## Set max shield and optionally adjust current shield.[br]
## [param new_max]: New maximum shield value.[br]
## [param adjust_current]: If true, scale current shield proportionally.
func set_max_shield(new_max: float, adjust_current: bool = false) -> void:
	if adjust_current and max_shield > 0.0:
		var ratio := current_shield / max_shield
		max_shield = new_max
		current_shield = new_max * ratio
	else:
		max_shield = new_max
		current_shield = minf(current_shield, max_shield)


## Set current health directly (for initialization/debugging).[br]
## [param value]: New health value (clamped to 0-max).
func set_health(value: float) -> void:
	current_health = clampf(value, 0.0, max_health)


## Set current shield directly (for initialization/debugging).[br]
## [param value]: New shield value (clamped to 0-max).
func set_shield(value: float) -> void:
	current_shield = clampf(value, 0.0, max_shield)
