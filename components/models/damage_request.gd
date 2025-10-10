class_name DamageRequest
extends RefCounted

## Data class containing damage information from attacker to defender.[br]
##[br]
## This is a lightweight snapshot of calculated attack data. The source is stored as a WeakRef[br]
## to prevent memory leaks - bullets can carry this request safely even if the shooter dies.[br]
## The defender (HealthComponent) processes this request and returns a DamageResult.

## Direct reference to damage source (fast access, can be null if source freed)
var source: Node = null

## Weak reference to source for safe checking
var _source_ref: WeakRef = null

## Calculated final damage amount
var damage: float = 0.0

## Damage type enum (0 = physical, 1 = fire, etc.)
var damage_type: int = 0

## Critical hit chance for receiver to manipulate (0.0 to 1.0)
var crit_chance: float = 0.0

## Critical damage multiplier if crit (1.5 = 150%)
var crit_damage: float = 1.5

## Optional knockback vector
var knockback: Vector2 = Vector2.ZERO

## Constructor.[br]
## [param _source]: Who/what caused damage (can be null).[br]
## [param _damage]: Calculated final damage.[br]
## [param _type]: Damage type enum.
func _init(_source: Node = null, _damage: float = 0.0, _type: int = 0) -> void:
	damage = _damage
	damage_type = _type
	set_source(_source)


## Set the damage source with weak reference tracking.[br]
## [param _source]: The Node that caused this damage.
func set_source(_source: Node) -> void:
	source = _source
	if _source:
		_source_ref = weakref(_source)
	else:
		_source_ref = null


## Get the damage source if still valid.[br]
## [return]: Source Node if valid, null if freed.
func get_source() -> Node:
	if _source_ref:
		var ref_source = _source_ref.get_ref()
		if is_instance_valid(ref_source):
			return ref_source
		else:
			# Source was freed, clear references
			source = null
			_source_ref = null
	return source


## Check if source is still valid.[br]
## [return]: true if source exists and hasn't been freed.
func is_source_valid() -> bool:
	return get_source() != null