class_name StatBasedHealthComponent
extends BaseHealthComponent

## Stat-based health component that integrates with the Stat system.[br]
##[br]
## This component uses Stat objects for health, shield, resistances, and damage modifiers.[br]
## All values are retrieved directly from stats - no caching or copying to base properties.[br]
## Automatically reacts to stat changes through signal connections.

## Reference to the entity's health stat (required)
var health_stat: Stat = null

## Reference to the entity's shield stat (optional, only if shield_enabled)
var shield_stat: Stat = null

## Reference to incoming damage multiplier stat (optional, e.g., "damage_reduction")
var damage_multiplier_stat: Stat = null

## Reference to flat damage reduction stat (optional, e.g., "armor")
var damage_reduction_stat: Stat = null

## Name of the health stat property on owner
var health_stat_name: String = "health"

## Name of the shield stat property on owner (if shield_enabled)
var shield_stat_name: String = "shield"

## Name of damage multiplier stat on owner (e.g., "damage_reduction")
var damage_multiplier_stat_name: String = "damage_reduction"

## Name of flat damage reduction stat on owner (e.g., "armor")
var damage_reduction_stat_name: String = "armor"

## Cached resistance stats by damage type (optimization)
var _resistance_cache: Dictionary = {}  # {damage_type: Stat}

## Constructor.[br]
## [param _owner]: The Node that owns this component (must have health stat).[br]
## [param _iframe_duration]: Seconds of invulnerability after taking damage (0.0 = disabled).[br]
## [param _shield_enabled]: Whether to process shield damage (requires shield stat on owner).[br]
## [param _health_stat_name]: Name of the health stat property on owner.[br]
## [param _shield_stat_name]: Name of the shield stat property on owner.[br]
## [param _max_damage_per_hit]: Maximum damage allowed per hit (0.0 = no limit).[br]
## [param _prevent_death_once]: Whether to prevent death once at 1 HP.[br]
## [param _immune_damage_types]: Array of damage types to completely ignore.
func _init(
	_owner: Node,
	_iframe_duration: float = 0.0,
	_shield_enabled: bool = false,
	_health_stat_name: String = "health",
	_shield_stat_name: String = "shield",
	_max_damage_per_hit: float = 0.0,
	_prevent_death_once: bool = false,
	_immune_damage_types: Array[int] = []
) -> void:
	super._init(_owner, _iframe_duration, _shield_enabled, _max_damage_per_hit, _prevent_death_once, _immune_damage_types)
	
	health_stat_name = _health_stat_name
	shield_stat_name = _shield_stat_name
	
	# Retrieve health stat safely via static helper
	health_stat = Stat.get_stat(owner, health_stat_name)
	
	if health_stat:
		health_stat.value_changed.connect(_on_health_changed)
	else:
		push_error("StatBasedHealthComponent: Owner must have a '%s' Stat property" % health_stat_name)
	
	# Retrieve shield stat if enabled
	if shield_enabled:
		shield_stat = Stat.get_stat(owner, shield_stat_name)
		
		if shield_stat:
			shield_stat.value_changed.connect(_on_shield_changed)
		else:
			push_warning("StatBasedHealthComponent: shield_enabled=true but owner has no '%s' Stat" % shield_stat_name)
			shield_enabled = false
	
	# Retrieve damage modifier stats if they exist (optional)
	damage_multiplier_stat = Stat.get_stat(owner, damage_multiplier_stat_name)
	damage_reduction_stat = Stat.get_stat(owner, damage_reduction_stat_name)


## Internal: Handle health stat changes (death detection).[br]
## [param new_value]: Current health value.[br]
## [param old_value]: Previous health value.
func _on_health_changed(new_value: float, _new_max: float, old_value: float, _old_max: float) -> void:
	# Detect death once
	if new_value <= 0.0 and not is_dead:
		is_dead = true
		died.emit()
	# Auto-revive if healed back from zero
	elif is_dead and new_value > 0.0:
		is_dead = false
	
	# Detect external healing (health increased outside of process_damage)
	if new_value > old_value:
		var heal_amount := new_value - old_value
		healed.emit(heal_amount)
	# Detect external damage (health decreased outside of process_damage)
	elif new_value < old_value:
		var damage_amount := old_value - new_value
		# Create a pseudo damage result for external damage tracking
		var pseudo_request := DamageRequest.new(null, damage_amount, 0)
		var pseudo_result := DamageResult.new(pseudo_request)
		pseudo_result.actual_damage = damage_amount
		damage_taken.emit(pseudo_result)


## Internal: Handle shield stat changes (shield break detection).[br]
## [param new_value]: Current shield value.[br]
## [param old_value]: Previous shield value.
func _on_shield_changed(new_value: float, _new_max: float, old_value: float, _old_max: float) -> void:
	# Detect shield break (went from >0 to 0)
	if old_value > 0.0 and new_value <= 0.0:
		shield_broken.emit(0.0)
	
	# Detect external shield restoration (increased outside of restore_shield)
	if new_value > old_value:
		var restore_amount := new_value - old_value
		shield_restored.emit(restore_amount)
	# Detect external shield damage (decreased outside of process_damage)
	elif new_value < old_value:
		var damage_amount := old_value - new_value
		shield_damaged.emit(damage_amount)


## Get current health value (override).[br]
## [return]: Current health or 0.0 if no health stat.
func get_health() -> float:
	return health_stat.get_value() if health_stat else 0.0


## Get maximum health value (override).[br]
## [return]: Max health or 0.0 if no health stat.
func get_max_health() -> float:
	return health_stat.get_max() if health_stat else 0.0


## Get current shield value (override).[br]
## [return]: Current shield or 0.0 if shield not enabled/found.
func get_shield() -> float:
	return shield_stat.get_value() if (shield_enabled and shield_stat) else 0.0


## Get maximum shield value (override).[br]
## [return]: Max shield or 0.0 if shield not enabled/found.
func get_max_shield() -> float:
	return shield_stat.get_max() if (shield_enabled and shield_stat) else 0.0


## Internal: Modify health by delta amount (override).[br]
## [param delta]: Amount to change health by (positive = heal, negative = damage).
func _modify_health(delta: float) -> void:
	if health_stat:
		health_stat.add_value(delta)


## Internal: Set health to specific value (override).[br]
## [param value]: New health value.
func _set_health(value: float) -> void:
	if health_stat:
		health_stat.set_value(value)


## Internal: Modify shield by delta amount (override).[br]
## [param delta]: Amount to change shield by (positive = restore, negative = damage).
func _modify_shield(delta: float) -> void:
	if shield_stat:
		shield_stat.add_value(delta)


## Internal: Get resistance value for damage type (override).[br]
## [param damage_type]: The damage type to get resistance for.[br]
## [return]: Resistance value (0.0 to 1.0).
func _get_resistance(damage_type: int) -> float:
	var resist_stat := _get_resistance_stat(damage_type)
	return resist_stat.get_value() if resist_stat else 0.0


## Internal: Get flat damage reduction value (override).[br]
## [return]: Flat damage reduction amount.
func _get_damage_reduction() -> float:
	return damage_reduction_stat.get_value() if damage_reduction_stat else 0.0


## Internal: Get damage multiplier (override).[br]
## [return]: Damage multiplier (1.0 = 100%, 0.5 = 50% damage taken).
func _get_damage_multiplier() -> float:
	return damage_multiplier_stat.get_value() if damage_multiplier_stat else 1.0


## Internal: Get resistance stat for damage type (with caching).[br]
## [param damage_type]: The damage type to get resistance for.[br]
## [return]: The resistance Stat or null if not found.
func _get_resistance_stat(damage_type: int) -> Stat:
	# Check cache first
	if _resistance_cache.has(damage_type):
		return _resistance_cache[damage_type]
	
	# Lookup and cache
	var resist_stat := Stat.get_stat(owner, resistance_stat_prefix + str(damage_type))
	_resistance_cache[damage_type] = resist_stat
	return resist_stat


## Enable or disable shield processing (override).[br]
## [param enabled]: Whether shield should be processed.[br]
## [return]: true if successfully enabled (requires shield stat on owner).
func set_shield_enabled(enabled: bool) -> bool:
	if enabled and not shield_stat:
		# Try to get shield stat
		shield_stat = Stat.get_stat(owner, shield_stat_name)
		if shield_stat:
			shield_stat.value_changed.connect(_on_shield_changed)
			shield_enabled = true
			return true
		else:
			push_warning("StatBasedHealthComponent: Cannot enable shield - owner has no '%s' Stat" % shield_stat_name)
			return false
	elif not enabled:
		shield_enabled = false
		return true
	
	return shield_enabled


## Clear the resistance stat cache (call if owner's stats change at runtime).[br]
## This is rarely needed as stats are typically set at creation.
func clear_resistance_cache() -> void:
	_resistance_cache.clear()
