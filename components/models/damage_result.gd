class_name DamageResult
extends RefCounted

## Result data class returned after damage processing.[br]
##[br]
## Contains the outcome of a damage request including actual damage dealt, shield damage,[br]
## crit status, and other information useful for attacker feedback (lifesteal, on-kill effects, etc.).[br]
## This is returned by HealthComponent.process_damage() to inform the attacker what happened.

## Reference to the original damage request
var request: DamageRequest = null

## Actual damage dealt to health after all calculations
var actual_damage: float = 0.0

## Amount of damage absorbed by shield
var shield_damaged: float = 0.0

## Whether the hit was a critical hit
var was_critical: bool = false

## Whether damage was blocked (invulnerable/dodged)
var was_blocked: bool = false

## Damage beyond 0 HP (useful for overkill mechanics)
var overkill: float = 0.0

## Constructor.[br]
## [param _request]: The original DamageRequest that was processed.
func _init(_request: DamageRequest) -> void:
	request = _request


## Get total damage dealt (shield + health).[br]
## [return]: Combined damage to shield and health.
func get_total_damage() -> float:
	return shield_damaged + actual_damage


## Check if any damage was dealt.[br]
## [return]: true if shield or health took damage.
func dealt_damage() -> bool:
	return get_total_damage() > 0.0


## Check if target was killed.[br]
## [return]: true if overkill is greater than 0 (health went below 0).
func was_fatal() -> bool:
	return overkill > 0.0


## Get the damage source from request (if still valid).[br]
## [return]: Source Node if valid, null if freed or blocked.
func get_source() -> Node:
	if request:
		return request.get_source()
	return null


## Check if source is still valid.[br]
## [return]: true if request has valid source.
func is_source_valid() -> bool:
	if request:
		return request.is_source_valid()
	return false