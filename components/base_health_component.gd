class_name BaseHealthComponent
extends RefCounted

## Abstract base health component defining the interface for health management.[br]
##[br]
## This is a pure interface class that defines the contract for health components.[br]
## It contains no storage properties (health, shield, etc.) - derived classes implement[br]
## their own storage mechanisms (simple floats or Stat references).[br]
## All damage processing logic and calculations are handled here.

## Reference to the entity that owns this component
var owner: Node = null

## Optional damage calculator for custom damage formulas
var damage_calculator: DamageCalculator = null

## Death state tracking
var is_dead: bool = false

## Invulnerability frame timer (counts down)
var iframe_timer: float = 0.0

## Duration of invulnerability after taking damage
var iframe_duration: float = 0.0

## Whether invulnerability frames are enabled
var iframe_enabled: bool = true

## Whether shield processing is enabled
var shield_enabled: bool = false

## Maximum damage per hit (0.0 = no limit, static value)
var max_damage_per_hit: float = 0.0

## Prevent death once at 1 HP (single-use, resets on revive)
var prevent_death_once: bool = false

## Internal flag tracking if death prevention was used
var _death_prevented: bool = false

## Array of damage types that are completely ignored
var immune_damage_types: Array[int] = []

## Prefix for resistance stat names (e.g., "resist_" + damage_type)
var resistance_stat_prefix: String = "resist_"

## Emitted when damage is successfully applied (includes blocked damage).[br]
## [param result]: DamageResult containing actual damage dealt and flags.
signal damage_taken(result: DamageResult)

## Emitted once when health reaches 0.
signal died()

## Emitted when entity is revived (optional hook for external systems).
signal revived()

## Emitted when invulnerability frames start.[br]
## [param duration]: Duration of the invulnerability frames.
signal iframe_started(duration: float)

## Emitted when invulnerability frames end naturally (not from death/revive).
signal iframe_ended()

## Emitted when a critical hit is received.[br]
## [param result]: DamageResult containing the critical hit data.
signal critical_hit_taken(result: DamageResult)

## Emitted when damage is blocked due to invulnerability.[br]
## [param request]: The DamageRequest that was blocked.
signal damage_blocked(request: DamageRequest)

## Emitted when healing is applied.[br]
## [param amount]: Amount of health restored.
signal healed(amount: float)

## Emitted when shield absorbs damage.[br]
## [param amount]: Amount of damage absorbed by shield.
signal shield_damaged(amount: float)

## Emitted when shield is depleted (goes to 0).[br]
## [param overkill]: Damage that went through to health after shield broke.
signal shield_broken(overkill: float)

## Emitted when shield is restored/recharged.[br]
## [param amount]: Amount of shield restored.
signal shield_restored(amount: float)

## Emitted when death is prevented by prevent_death_once.[br]
## [param request]: The DamageRequest that would have killed.
signal death_prevented(request: DamageRequest)

## Emitted when damage is negated due to type immunity.[br]
## [param damage_type]: The damage type that was ignored.
signal damage_immunity_triggered(damage_type: int)

## Constructor.[br]
## [param _owner]: The Node that owns this component.[br]
## [param _iframe_duration]: Seconds of invulnerability after taking damage (0.0 = disabled).[br]
## [param _shield_enabled]: Whether to process shield damage.[br]
## [param _max_damage_per_hit]: Maximum damage allowed per hit (0.0 = no limit).[br]
## [param _prevent_death_once]: Whether to prevent death once at 1 HP.[br]
## [param _immune_damage_types]: Array of damage types to completely ignore.
func _init(
	_owner: Node,
	_iframe_duration: float = 0.0,
	_shield_enabled: bool = false,
	_max_damage_per_hit: float = 0.0,
	_prevent_death_once: bool = false,
	_immune_damage_types: Array[int] = []
) -> void:
	owner = _owner
	iframe_duration = _iframe_duration
	shield_enabled = _shield_enabled
	max_damage_per_hit = _max_damage_per_hit
	prevent_death_once = _prevent_death_once
	immune_damage_types = _immune_damage_types.duplicate()


## Process incoming damage request and return result.[br]
## [param request]: DamageRequest containing damage data from attacker.[br]
## [return]: DamageResult with actual damage dealt and flags.
func process_damage(request: DamageRequest) -> DamageResult:
	var result := DamageResult.new(request)
	
	# Check damage type immunity first (before any other checks)
	if immune_damage_types.has(request.damage_type):
		result.was_blocked = true
		damage_immunity_triggered.emit(request.damage_type)
		damage_taken.emit(result)
		return result
	
	# Check invulnerability (dead or iframes active)
	if is_dead or (iframe_enabled and iframe_timer > 0.0):
		result.was_blocked = true
		damage_blocked.emit(request)
		damage_taken.emit(result)
		return result
	
	# Calculate incoming damage (use custom calculator if provided)
	var incoming: float
	if damage_calculator:
		incoming = damage_calculator.calculate_damage(request, self, result)
	else:
		# Default calculation
		result.was_critical = randf() < clampf(request.crit_chance, 0.0, 1.0)
		incoming = request.damage * (request.crit_damage if result.was_critical else 1.0)
		
		# Apply resistance by damage type
		var resistance := _get_resistance(request.damage_type)
		incoming *= (1.0 - clampf(resistance, 0.0, 0.9))  # Max 90% resist
		
		# Apply flat damage reduction (armor) - subtracts before multiplier
		var armor := _get_damage_reduction()
		incoming = maxf(0.0, incoming - armor)
		
		# Apply damage multiplier (damage reduction %) - multiplies remaining damage
		var multiplier := _get_damage_multiplier()
		incoming *= multiplier
		
		# Apply max damage cap (static limit)
		if max_damage_per_hit > 0.0:
			incoming = minf(incoming, max_damage_per_hit)
	
	# Apply damage (shield first if enabled, then health)
	_apply_damage(incoming, result)
	
	# Start iframes
	if result.actual_damage > 0.0 and iframe_enabled and iframe_duration > 0.0:
		iframe_timer = iframe_duration
		iframe_started.emit(iframe_duration)
	
	# Emit specialized signals
	if result.was_critical:
		critical_hit_taken.emit(result)
	
	damage_taken.emit(result)
	return result


## Internal: Apply damage to shield and/or health.[br]
## [param amount]: Raw damage amount (already calculated with resists/crits).[br]
## [param result]: DamageResult to update with overkill and shield damage data.
func _apply_damage(amount: float, result: DamageResult) -> void:
	var remaining_damage := amount
	
	# Apply to shield first if enabled
	if shield_enabled:
		var shield_value := get_shield()
		
		if shield_value > 0.0:
			var shield_absorbed := minf(remaining_damage, shield_value)
			_modify_shield(-shield_absorbed)
			result.shield_damaged = shield_absorbed
			shield_damaged.emit(shield_absorbed)
			remaining_damage -= shield_absorbed
			
			# Check if shield broke
			if get_shield() <= 0.0 and remaining_damage > 0.0:
				shield_broken.emit(remaining_damage)
	
	# Apply remaining damage to health
	if remaining_damage > 0.0:
		var old_health: float = get_health()
		
		# Check death prevention (only once, before damage applied)
		if prevent_death_once and not _death_prevented:
			var would_die := (old_health - remaining_damage) <= 0.0
			
			if would_die:
				# Reduce damage to leave entity at 1 HP
				remaining_damage = old_health - 1.0
				_death_prevented = true
				death_prevented.emit(result.request)
		
		_modify_health(-remaining_damage)
		
		# Set actual_damage to the damage that went to health
		result.actual_damage = remaining_damage
		
		# Calculate overkill (damage beyond 0 HP)
		var new_health := get_health()
		if new_health <= 0.0:
			result.overkill = remaining_damage - old_health
		
		# Check for death
		if new_health <= 0.0 and not is_dead:
			is_dead = true
			died.emit()
	else:
		# All damage absorbed by shield, no health damage
		result.actual_damage = 0.0


## Heal health by specified amount.[br]
## [param amount]: Amount to heal (positive value).[br]
## [return]: Actual amount healed (may be less if clamped to max HP).
func heal(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	
	var old_health := get_health()
	_modify_health(amount)
	var new_health := get_health()
	
	var actual_healed := new_health - old_health
	if actual_healed > 0.0:
		healed.emit(actual_healed)
		
		# Auto-revive if healed back from zero
		if is_dead and new_health > 0.0:
			is_dead = false
	
	return actual_healed


## Restore shield by specified amount.[br]
## [param amount]: Amount to restore (positive value).[br]
## [return]: Actual amount restored (may be less if clamped to max shield).
func restore_shield(amount: float) -> float:
	if not shield_enabled or amount <= 0.0:
		return 0.0
	
	var old_shield := get_shield()
	_modify_shield(amount)
	var new_shield := get_shield()
	
	var actual_restored := new_shield - old_shield
	if actual_restored > 0.0:
		shield_restored.emit(actual_restored)
	
	return actual_restored


## Update timers – call in owner's _process or _physics_process.[br]
## [param delta]: Time elapsed since last frame.
func update(delta: float) -> void:
	if iframe_enabled and iframe_timer > 0.0:
		var was_active := iframe_timer > 0.0
		iframe_timer -= delta
		
		# Detect when iframes end naturally
		if was_active and iframe_timer <= 0.0:
			iframe_ended.emit()


## Check invulnerability.[br]
## [return]: true if dead or iframes active (and enabled).
func is_invulnerable() -> bool:
	return is_dead or (iframe_enabled and iframe_timer > 0.0)


## Check if health is at maximum.[br]
## [return]: true if health equals max health.
func is_full_health() -> bool:
	return get_health() >= get_max_health()


## Check if shield is at maximum.[br]
## [return]: true if shield equals max shield.
func is_full_shield() -> bool:
	if not shield_enabled:
		return false
	return get_shield() >= get_max_shield()


## Get iframe remaining fraction (0.0 to 1.0).[br]
## [return]: Fraction of iframe duration remaining (1.0 = just started, 0.0 = ended).
func get_iframe_fraction() -> float:
	if not iframe_enabled or iframe_duration <= 0.0:
		return 0.0
	return clampf(iframe_timer / iframe_duration, 0.0, 1.0)


## Get iframe remaining time in seconds.[br]
## [return]: Seconds remaining of invulnerability.
func get_iframe_remaining() -> float:
	return maxf(0.0, iframe_timer) if iframe_enabled else 0.0


## Revive the entity (resets death state; does NOT restore health).[br]
## Use heal() after revive() to restore HP.
func revive() -> void:
	is_dead = false
	iframe_timer = 0.0
	_death_prevented = false
	revived.emit()


## Forcefully kills the entity immediately.
func force_kill() -> void:
	_set_health(0.0)
	if not is_dead:
		is_dead = true
		died.emit()


## Manually start invulnerability frames (useful for abilities/effects).[br]
## [param duration]: Duration of invulnerability in seconds.
func start_iframe(duration: float) -> void:
	if iframe_enabled and duration > 0.0:
		iframe_timer = duration
		iframe_started.emit(duration)


## Manually end invulnerability frames early.
func end_iframe() -> void:
	if iframe_enabled and iframe_timer > 0.0:
		iframe_timer = 0.0
		iframe_ended.emit()


## Enable or disable invulnerability frame processing.[br]
## [param enabled]: Whether iframes should be active.
func set_iframe_enabled(enabled: bool) -> void:
	var was_enabled := iframe_enabled
	iframe_enabled = enabled
	
	# If disabling while iframes active, end them
	if was_enabled and not enabled and iframe_timer > 0.0:
		iframe_timer = 0.0
		iframe_ended.emit()


## Enable or disable shield processing.[br]
## [param enabled]: Whether shield should be processed.[br]
## [return]: true if successfully enabled.
func set_shield_enabled(enabled: bool) -> bool:
	shield_enabled = enabled
	return shield_enabled


## Add a damage type to immunity list.[br]
## [param damage_type]: The damage type to ignore.
func add_damage_immunity(damage_type: int) -> void:
	if not immune_damage_types.has(damage_type):
		immune_damage_types.append(damage_type)


## Remove a damage type from immunity list.[br]
## [param damage_type]: The damage type to stop ignoring.
func remove_damage_immunity(damage_type: int) -> void:
	immune_damage_types.erase(damage_type)


## Check if immune to a specific damage type.[br]
## [param damage_type]: The damage type to check.[br]
## [return]: true if immune to this damage type.
func is_immune_to(damage_type: int) -> bool:
	return immune_damage_types.has(damage_type)


## Reset death prevention flag (allows it to trigger again).[br]
## Automatically called on revive().
func reset_death_prevention() -> void:
	_death_prevented = false


## Check if death prevention has been used.[br]
## [return]: true if death was prevented and flag not reset.
func was_death_prevented() -> bool:
	return _death_prevented


## Set a custom damage calculator.[br]
## [param calculator]: DamageCalculator instance or null to use default.
func set_damage_calculator(calculator: DamageCalculator) -> void:
	damage_calculator = calculator


## Get the current damage calculator.[br]
## [return]: Current DamageCalculator or null if using default.
func get_damage_calculator() -> DamageCalculator:
	return damage_calculator


# ============================================================================
# VIRTUAL METHODS - MUST BE OVERRIDDEN BY DERIVED CLASSES
# ============================================================================

## Get current health value.[br]
## [return]: Current health.
func get_health() -> float:
	push_error("BaseHealthComponent.get_health() must be overridden")
	return 0.0


## Get maximum health value.[br]
## [return]: Max health.
func get_max_health() -> float:
	push_error("BaseHealthComponent.get_max_health() must be overridden")
	return 0.0


## Get current shield value.[br]
## [return]: Current shield (0.0 if shield not enabled).
func get_shield() -> float:
	return 0.0  # Optional override


## Get maximum shield value.[br]
## [return]: Max shield (0.0 if shield not enabled).
func get_max_shield() -> float:
	return 0.0  # Optional override


## Internal: Modify health by delta amount (handles clamping).[br]
## [param delta]: Amount to change health by (positive = heal, negative = damage).
func _modify_health(_delta: float) -> void:
	push_error("BaseHealthComponent._modify_health() must be overridden")


## Internal: Set health to specific value (used by force_kill).[br]
## [param value]: New health value.
func _set_health(_value: float) -> void:
	push_error("BaseHealthComponent._set_health() must be overridden")


## Internal: Modify shield by delta amount (handles clamping).[br]
## [param delta]: Amount to change shield by (positive = restore, negative = damage).
func _modify_shield(_delta: float) -> void:
	pass  # Optional override


## Internal: Get resistance value for damage type.[br]
## [param damage_type]: The damage type to get resistance for.[br]
## [return]: Resistance value (0.0 to 1.0).
func _get_resistance(_damage_type: int) -> float:
	return 0.0  # Optional override


## Internal: Get flat damage reduction value (armor).[br]
## [return]: Flat damage reduction amount.
func _get_damage_reduction() -> float:
	return 0.0  # Optional override


## Internal: Get damage multiplier (percentage reduction).[br]
## [return]: Damage multiplier (1.0 = 100%, 0.5 = 50% damage taken).
func _get_damage_multiplier() -> float:
	return 1.0  # Optional override
