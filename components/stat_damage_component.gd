class_name StatDamageComponent
extends DamageComponent

## Stat-based damage component that calculates damage from owner's stats.[br]
##[br]
## This component extends DamageComponent to support complex damage calculations based on[br]
## the owner's stat values. It uses hybrid scaling (flat + percentage) and automatically[br]
## pulls crit stats from the owner if available. Stats are cached on initialization for[br]
## performance and updated when stat values change via signals.

## Base weapon/ability damage (before scaling)
var base_damage: float = 10.0

## Attack stat scaling multiplier (0.8 = 80% of attack added to base)
var damage_scaling: float = 0.8

## Cached reference to owner's attack stat
var attack_stat: Stat = null

## Cached reference to owner's attack percent stat (bonus damage multiplier)
var attack_percent_stat: Stat = null

## Cached reference to owner's crit chance stat
var crit_chance_stat: Stat = null

## Cached reference to owner's crit damage stat
var crit_damage_stat: Stat = null

## Name of attack stat on owner
var attack_stat_name: String = "attack"

## Name of attack percent stat on owner
var attack_percent_stat_name: String = "attack_percent"

## Name of crit chance stat on owner
var crit_chance_stat_name: String = "crit_chance"

## Name of crit damage stat on owner
var crit_damage_stat_name: String = "crit_damage"

## Whether to automatically recalculate damage when stats change
var auto_update_on_stat_change: bool = true

## Cached calculated damage (updated when stats change)
var _cached_damage: float = 0.0

## Whether cache is dirty and needs recalculation
var _damage_cache_dirty: bool = true

## Constructor.[br]
## [param _owner]: The Object that owns this component (must have attack stats).[br]
## [param _base_damage]: Base damage before stat scaling.[br]
## [param _damage_scaling]: Multiplier for attack stat (0.8 = 80% of attack).
func _init(_owner: Object, _base_damage: float = 10.0, _damage_scaling: float = 0.8) -> void:
	super._init(_owner)
	base_damage = _base_damage
	damage_scaling = _damage_scaling
	
	# Cache stat references (no signal connections)
	_cache_stat_references()


## Internal: Cache all stat references from owner.[br]
## Called during initialization to avoid repeated lookups.
func _cache_stat_references() -> void:
	if not owner:
		return
	
	# Attack stats for damage calculation
	attack_stat = Stat.get_stat(owner, attack_stat_name)
	attack_percent_stat = Stat.get_stat(owner, attack_percent_stat_name)
	
	# Crit stats
	crit_chance_stat = Stat.get_stat(owner, crit_chance_stat_name)
	crit_damage_stat = Stat.get_stat(owner, crit_damage_stat_name)


## Internal: Connect to stat value_changed signals for automatic updates.[br]
## When stats change (from buffs, upgrades, etc.), damage is recalculated.
func _connect_stat_signals() -> void:
	# REMOVED: No longer auto-updating on stat changes
	# Damage is calculated when create_request() is called
	pass


## Internal: Handle stat value changes - mark cache as dirty.[br]
## [param new_value]: New stat value (unused, just triggers recalc).[br]
## [param new_max]: New max value (unused).[br]
## [param old_value]: Old stat value (unused).[br]
## [param old_max]: Old max value (unused).
func _on_stat_changed(_new_value: float, _new_max: float, _old_value: float, _old_max: float) -> void:
	# REMOVED: No longer needed
	pass


## Internal: Recalculate damage from current stat values.[br]
## Uses hybrid formula: base + (attack × scaling) × (1 + attack_percent).
func _recalculate_damage() -> void:
	# Start with base damage
	var calculated_damage := base_damage
	
	# Add flat attack scaling
	if attack_stat:
		var attack_value := attack_stat.get_value()
		calculated_damage += (attack_value * damage_scaling)
	
	# Apply percentage multiplier
	if attack_percent_stat:
		var attack_percent := attack_percent_stat.get_value()
		calculated_damage *= (1.0 + attack_percent)
	
	# Update cached damage
	_cached_damage = calculated_damage
	damage = calculated_damage
	
	# Update crit stats from owner
	if crit_chance_stat:
		crit_chance = crit_chance_stat.get_value()
	
	if crit_damage_stat:
		# Stat stores BONUS (0.5 = +50%), convert to MULTIPLIER (1.5 = 150%)
		crit_damage = 1.0 + crit_damage_stat.get_value()
	
	_damage_cache_dirty = false


## Create a DamageRequest with stat-calculated damage.[br]
## Recalculates damage from current stat values every time (fresh snapshot).[br]
## [return]: New DamageRequest with current calculated damage values.
func create_request() -> DamageRequest:
	# Always recalculate for fresh stat snapshot
	_recalculate_damage()
	
	# Use parent's create_request with updated damage values
	return super.create_request()


## Get current calculated damage without creating a request.[br]
## Recalculates from current stat values.[br]
## [return]: Current damage value based on stats.
func get_calculated_damage() -> float:
	_recalculate_damage()
	return _cached_damage


## Force recalculation of damage from current stats.[br]
## Useful if you need to pre-calculate for UI display.
func force_recalculate() -> void:
	_recalculate_damage()


## Refresh stat references from owner.[br]
## Call this if owner's stats were added/changed after initialization.
func refresh_stat_references() -> void:
	# Re-cache (no signal connections to disconnect)
	_cache_stat_references()


## Copy all properties from another DamageComponent (override).[br]
## [param other]: The DamageComponent to copy from.[br]
## [param copy_owner]: Whether to also copy the owner reference.
func copy_from(other: DamageComponent, copy_owner: bool = true) -> void:
	# Call parent copy
	super.copy_from(other, copy_owner)
	
	# If copying from another StatBasedDamageComponent, copy extra properties
	if other is StatDamageComponent:
		base_damage = other.base_damage
		damage_scaling = other.damage_scaling
		
		# Copy stat name configuration
		attack_stat_name = other.attack_stat_name
		attack_percent_stat_name = other.attack_percent_stat_name
		crit_chance_stat_name = other.crit_chance_stat_name
		crit_damage_stat_name = other.crit_damage_stat_name
		
		# Refresh stat references for new owner
		if copy_owner:
			refresh_stat_references()


## Set custom stat names (if owner uses different naming).[br]
## [param _attack]: Name of attack stat.[br]
## [param _attack_percent]: Name of attack percent stat.[br]
## [param _crit_chance]: Name of crit chance stat.[br]
## [param _crit_damage]: Name of crit damage stat.
func set_stat_names(
	_attack: String = "attack",
	_attack_percent: String = "attack_percent",
	_crit_chance: String = "crit_chance",
	_crit_damage: String = "crit_damage"
) -> void:
	attack_stat_name = _attack
	attack_percent_stat_name = _attack_percent
	crit_chance_stat_name = _crit_chance
	crit_damage_stat_name = _crit_damage
	
	# Refresh with new names
	refresh_stat_references()