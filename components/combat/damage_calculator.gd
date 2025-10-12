class_name DamageCalculator
extends RefCounted

## Base damage calculator for health components.[br]
##[br]
## This calculator handles the default damage calculation pipeline: critical hits,[br]
## resistances, armor, damage multipliers, and damage caps. Custom calculators can[br]
## extend this class to implement different damage formulas while reusing parts of[br]
## the default logic.

## Calculate incoming damage from a damage request.[br]
## [param request]: The incoming DamageRequest.[br]
## [param health_component]: The health component receiving damage (for accessing stats/properties).[br]
## [param result]: The DamageResult being built (for setting flags like was_critical).[br]
## [return]: Final calculated damage amount.
func calculate_damage(request: DamageRequest, health_component: HealthComponent, result: DamageResult) -> float:
	# Roll critical hit
	result.was_critical = randf() < clampf(request.crit_chance, 0.0, 1.0)
	var incoming := request.damage * (request.crit_damage if result.was_critical else 1.0)
	
	# Apply resistance by damage type
	var resistance = health_component._get_resistance(request.damage_type)
	incoming *= (1.0 - clampf(resistance, 0.0, 0.9))  # Max 90% resist
	
	# Apply flat damage reduction (armor) - subtracts before multiplier
	var armor = health_component._get_damage_reduction()
	incoming = maxf(0.0, incoming - armor)
	
	# Apply damage multiplier (damage reduction %) - multiplies remaining damage
	var multiplier = health_component._get_damage_multiplier()
	incoming *= multiplier
	
	# Apply max damage cap (static limit)
	if health_component.max_damage_per_hit > 0.0:
		incoming = minf(incoming, health_component.max_damage_per_hit)
	
	return incoming


## Override this to customize critical hit calculation.[br]
## [param request]: The incoming DamageRequest.[br]
## [param result]: The DamageResult to set was_critical flag.[br]
## [return]: Damage multiplier (1.0 = normal, request.crit_damage = critical).
func calculate_critical(request: DamageRequest, result: DamageResult) -> float:
	result.was_critical = randf() < clampf(request.crit_chance, 0.0, 1.0)
	return request.crit_damage if result.was_critical else 1.0


## Override this to customize resistance application.[br]
## [param incoming_damage]: Current damage before resistance.[br]
## [param resistance]: Resistance value (0.0 to 1.0).[br]
## [return]: Damage after resistance applied.
func apply_resistance(incoming_damage: float, resistance: float) -> float:
	return incoming_damage * (1.0 - clampf(resistance, 0.0, 0.9))


## Override this to customize flat damage reduction (armor).[br]
## [param incoming_damage]: Current damage before armor.[br]
## [param armor]: Flat damage reduction amount.[br]
## [return]: Damage after armor applied.
func apply_armor(incoming_damage: float, armor: float) -> float:
	return maxf(0.0, incoming_damage - armor)


## Override this to customize damage multiplier application.[br]
## [param incoming_damage]: Current damage before multiplier.[br]
## [param multiplier]: Damage multiplier (1.0 = 100%, 0.5 = 50%).[br]
## [return]: Damage after multiplier applied.
func apply_multiplier(incoming_damage: float, multiplier: float) -> float:
	return incoming_damage * multiplier


## Override this to customize damage cap logic.[br]
## [param incoming_damage]: Current damage before cap.[br]
## [param max_damage]: Maximum allowed damage per hit (0.0 = no cap).[br]
## [return]: Damage after cap applied.
func apply_damage_cap(incoming_damage: float, max_damage: float) -> float:
	if max_damage > 0.0:
		return minf(incoming_damage, max_damage)
	return incoming_damage
