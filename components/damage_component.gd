class_name DamageComponent
extends RefCounted

## Core damage component that creates DamageRequests for simple entities.[br]
##[br]
## This component handles basic damage calculations with fixed values. For stat-based[br]
## damage scaling, use StatBasedDamageComponent which extends this class.[br]
## The component can apply damage directly to targets or create requests for manual handling.

## Reference to the entity that owns this component
var owner: Node = null

## Base damage amount (fixed value)
var damage: float = 10.0

## Damage type identifier (0 = physical, 1 = fire, etc.)
var damage_type: int = 0

## Critical hit chance (0.0 to 1.0)
var crit_chance: float = 0.0

## Critical damage multiplier (1.5 = 150% damage on crit)
var crit_damage: float = 1.5

## Knockback vector applied on hit
var knockback: Vector2 = Vector2.ZERO

## Emitted when damage is successfully applied to a target.[br]
## [param target]: The entity that was damaged.[br]
## [param result]: DamageResult containing actual damage dealt.
signal damage_applied(target: Node, result: DamageResult)

## Emitted when damage application fails (target has no process_damage method).[br]
## [param target]: The entity that couldn't be damaged.
signal damage_failed(target: Node)

## Constructor.[br]
## [param _owner]: The Node that owns this component (damage source).
func _init(_owner: Node = null) -> void:
	owner = _owner


## Create a DamageRequest with current damage values.[br]
## [return]: New DamageRequest ready to be processed, or null if owner is invalid.
func create_request() -> DamageRequest:
	# Check if owner is still valid
	var valid_owner := get_owner()
	
	var request := DamageRequest.new(valid_owner, damage, damage_type)
	request.crit_chance = crit_chance
	request.crit_damage = crit_damage
	request.knockback = knockback
	return request


## Apply damage directly to a target node.[br]
## [param target]: The node to damage (must have process_damage method).[br]
## [return]: DamageResult if successful, null if target can't be damaged.
func apply_to(target: Node) -> DamageResult:
	if not is_instance_valid(target) or not target.has_method("process_damage"):
		damage_failed.emit(target)
		return null
	
	var request := create_request()
	var result: DamageResult = target.process_damage(request)
	
	if result:
		damage_applied.emit(target, result)
	
	return result


## Set the owner node with weak reference tracking.[br]
## [param _owner]: The Node that owns this component.
func set_owner(_owner: Node) -> void:
	owner = _owner

## Get the owner node if still valid.[br]
## [return]: Owner Node if valid, null if freed.
func get_owner() -> Node:
	return owner


## Check if owner is still valid.[br]
## [return]: true if owner exists and hasn't been freed.
func is_owner_valid() -> bool:
	return get_owner() != null


## Copy all damage properties from another DamageComponent.[br]
## [param other]: The DamageComponent to copy from.[br]
## [param copy_owner]: Whether to also copy the owner reference.
func copy_from(other: DamageComponent, copy_owner: bool = true) -> void:
	if not other:
		return
	
	damage = other.damage
	damage_type = other.damage_type
	crit_chance = other.crit_chance
	crit_damage = other.crit_damage
	knockback = other.knockback
	
	if copy_owner:
		set_owner(other.get_owner())


## Set all damage properties at once (convenience method).[br]
## [param _damage]: Base damage amount.[br]
## [param _type]: Damage type identifier.[br]
## [param _crit_chance]: Critical hit chance (0.0-1.0).[br]
## [param _crit_damage]: Critical damage multiplier.[br]
## [param _knockback]: Knockback vector.
func set_damage_properties(
	_damage: float,
	_type: int = 0,
	_crit_chance: float = 0.0,
	_crit_damage: float = 1.5,
	_knockback: Vector2 = Vector2.ZERO
) -> void:
	damage = _damage
	damage_type = _type
	crit_chance = _crit_chance
	crit_damage = _crit_damage
	knockback = _knockback