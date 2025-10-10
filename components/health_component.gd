class_name HealthComponent
extends RefCounted

## Core health management component with damage processing, resistances, and invulnerability frames.[br]
##[br]
## This component handles all incoming damage processing including critical hits, resistances, and invulnerability[br]
## frames. It integrates with the Stat system for health management and supports healing. The component uses[br]
## duck typing for resistance stats, allowing flexible damage type systems without hard dependencies.[br]
## Optionally supports shield layers that absorb damage before health.

## Reference to the entity's health stat (required)
var health: Stat = null

## Reference to the entity's shield stat (optional, only if shield_enabled)
var shield: Stat = null

## Reference to incoming damage multiplier stat (optional, e.g., "damage_reduction")
var damage_multiplier_stat: Stat = null

## Reference to flat damage reduction stat (optional, e.g., "armor")
var damage_reduction_stat: Stat = null

## Reference to the entity that owns this component
var owner: Node = null

## Death state tracking
var is_dead: bool = false

## Invulnerability frame timer (counts down)
var iframe_timer: float = 0.0

## Duration of invulnerability after taking damage
var iframe_duration: float = 0.0

## Whether invulnerability frames are enabled
var iframe_enabled: bool = true

## Whether shield processing is enabled (requires "shield" Stat on owner)
var shield_enabled: bool = false

## Maximum damage per hit (0.0 = no limit, static value)
var max_damage_per_hit: float = 0.0

## Prevent death once at 1 HP (single-use, resets on revive)
var prevent_death_once: bool = false

## Internal flag tracking if death prevention was used
var _death_prevented: bool = false

## Array of damage types that are completely ignored
var immune_damage_types: Array[int] = []

## Name of the health stat property on owner
var health_stat_name: String = "health"

## Name of the shield stat property on owner (if shield_enabled)
var shield_stat_name: String = "shield"

## Name of damage multiplier stat on owner (e.g., "damage_reduction")
var damage_multiplier_stat_name: String = "damage_reduction"

## Name of flat damage reduction stat on owner (e.g., "armor")
var damage_reduction_stat_name: String = "armor"

## Prefix for resistance stat names (e.g., "resist_" + damage_type)
var resistance_stat_prefix: String = "resist_"

## Cached resistance stats by damage type (optimization)
var _resistance_cache: Dictionary = {}  # {damage_type: Stat}

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
	owner = _owner
	iframe_duration = _iframe_duration
	shield_enabled = _shield_enabled
	health_stat_name = _health_stat_name
	shield_stat_name = _shield_stat_name
	max_damage_per_hit = _max_damage_per_hit
	prevent_death_once = _prevent_death_once
	immune_damage_types = _immune_damage_types.duplicate()
	
	# Retrieve health stat safely via static helper
	health = Stat.get_stat(owner, health_stat_name)
	
	if health:
		health.value_changed.connect(_on_health_changed)
	else:
		push_error("HealthComponent: Owner must have a '%s' Stat property" % health_stat_name)
	
	# Retrieve shield stat if enabled
	if shield_enabled:
		shield = Stat.get_stat(owner, shield_stat_name)
		
		if shield:
			shield.value_changed.connect(_on_shield_changed)
		else:
			push_warning("HealthComponent: shield_enabled=true but owner has no '%s' Stat" % shield_stat_name)
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
	
	# Roll critical hit
	result.was_critical = randf() < clampf(request.crit_chance, 0.0, 1.0)
	var incoming := request.damage * (request.crit_damage if result.was_critical else 1.0)
	
	# Apply resistance by damage type (cached lookup for performance)
	var resist_stat := _get_resistance_stat(request.damage_type)
	if resist_stat:
		var resistance := resist_stat.get_value()
		incoming *= (1.0 - clampf(resistance, 0.0, 0.9))  # Max 90% resist
	
	# Apply flat damage reduction (armor) - subtracts before multiplier
	if damage_reduction_stat:
		var armor := damage_reduction_stat.get_value()
		incoming = maxf(0.0, incoming - armor)
	
	# Apply damage multiplier (damage reduction %) - multiplies remaining damage
	if damage_multiplier_stat:
		var multiplier := damage_multiplier_stat.get_value()
		incoming *= multiplier
	
	# Apply max damage cap (static limit)
	if max_damage_per_hit > 0.0:
		incoming = minf(incoming, max_damage_per_hit)
	
	# Apply damage (shield first if enabled, then health)
	result.actual_damage = incoming
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
	if shield_enabled and shield != null:
		var shield_value := shield.get_value()
		
		if shield_value > 0.0:
			var shield_absorbed := minf(remaining_damage, shield_value)
			shield.add_value(-shield_absorbed)
			result.shield_damaged = shield_absorbed  # Track in result
			shield_damaged.emit(shield_absorbed)
			remaining_damage -= shield_absorbed
			
			# Check if shield broke
			if shield.get_value() <= 0.0 and remaining_damage > 0.0:
				shield_broken.emit(remaining_damage)
	
	# Apply remaining damage to health
	if remaining_damage > 0.0 and health != null:
		var old_health: float = health.get_value()
		
		# Check death prevention (only once, before damage applied)
		if prevent_death_once and not _death_prevented:
			var would_die := (old_health - remaining_damage) <= 0.0
			
			if would_die:
				# Reduce damage to leave entity at 1 HP
				remaining_damage = old_health - 1.0
				_death_prevented = true
				death_prevented.emit(result.request)
		
		var _actual_change: float = health.add_value(-remaining_damage)
		
		# Calculate overkill (damage beyond 0 HP)
		if health.get_value() <= 0.0:
			result.overkill = remaining_damage - old_health


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


## Heal health by specified amount.[br]
## [param amount]: Amount to heal (positive value).[br]
## [return]: Actual amount healed (may be less if clamped to max HP).
func heal(amount: float) -> float:
	if is_dead or health == null:
		return 0.0
	
	var actual_healed := health.add_value(amount)
	if actual_healed > 0.0:
		healed.emit(actual_healed)
	
	return actual_healed


## Restore shield by specified amount.[br]
## [param amount]: Amount to restore (positive value).[br]
## [return]: Actual amount restored (may be less if clamped to max shield).
func restore_shield(amount: float) -> float:
	if not shield_enabled or shield == null:
		return 0.0
	
	var actual_restored := shield.add_value(amount)
	if actual_restored > 0.0:
		shield_restored.emit(actual_restored)
	
	return actual_restored


## Update timers — call in owner's _process or _physics_process.[br]
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


## Get current health value (convenience method).[br]
## [return]: Current health or 0.0 if no health stat.
func get_health() -> float:
	return health.get_value() if health else 0.0


## Get maximum health value (convenience method).[br]
## [return]: Max health or 0.0 if no health stat.
func get_max_health() -> float:
	return health.get_max() if health else 0.0


## Get current shield value (convenience method).[br]
## [return]: Current shield or 0.0 if shield not enabled/found.
func get_shield() -> float:
	return shield.get_value() if (shield_enabled and shield) else 0.0


## Get maximum shield value (convenience method).[br]
## [return]: Max shield or 0.0 if shield not enabled/found.
func get_max_shield() -> float:
	return shield.get_max() if (shield_enabled and shield) else 0.0


## Check if health is at maximum.[br]
## [return]: true if health equals max health.
func is_full_health() -> bool:
	return health.is_max() if health else false


## Check if shield is at maximum.[br]
## [return]: true if shield equals max shield.
func is_full_shield() -> bool:
	return shield.is_max() if (shield_enabled and shield) else false


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
	_death_prevented = false  # Reset death prevention on revive
	revived.emit()


## Forcefully kills the entity immediately.
func force_kill() -> void:
	if health:
		health.set_value(0.0)


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
## [return]: true if successfully enabled (requires shield stat on owner).
func set_shield_enabled(enabled: bool) -> bool:
	if enabled and not shield:
		# Try to get shield stat
		shield = Stat.get_stat(owner, shield_stat_name)
		if shield:
			shield.value_changed.connect(_on_shield_changed)
			shield_enabled = true
			return true
		else:
			push_warning("HealthComponent: Cannot enable shield - owner has no '%s' Stat" % shield_stat_name)
			return false
	elif not enabled:
		shield_enabled = false
		return true
	
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


## Clear the resistance stat cache (call if owner's stats change at runtime).[br]
## This is rarely needed as stats are typically set at creation.
func clear_resistance_cache() -> void:
	_resistance_cache.clear()


## Reset death prevention flag (allows it to trigger again).[br]
## Automatically called on revive().
func reset_death_prevention() -> void:
	_death_prevented = false


## Check if death prevention has been used.[br]
## [return]: true if death was prevented and flag not reset.
func was_death_prevented() -> bool:
	return _death_prevented