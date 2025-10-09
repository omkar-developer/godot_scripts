class_name HealthComponent
extends RefCounted

## Core health management component with damage processing, resistances, and invulnerability frames.[br]
## This component handles all incoming damage processing including critical hits, resistances, and invulnerability[br]
## frames. It integrates with the Stat system for health management and supports healing. The component uses[br]
## duck typing for resistance stats, allowing flexible damage type systems without hard dependencies.

## Reference to the entity's health stat (required)
var health: Stat = null

## Reference to the entity that owns this component
var owner: Node = null

## Death state tracking
var is_dead: bool = false

## Invulnerability frame timer (counts down)
var iframe_timer: float = 0.0

## Duration of invulnerability after taking damage
var iframe_duration: float = 0.0

## Emitted when damage is successfully applied (includes blocked damage).[br]
## [param result]: DamageResult containing actual damage dealt and flags.
signal damage_taken(result: DamageResult)

## Emitted once when health reaches 0.
signal died()

## Emitted when entity is revived (optional hook for external systems)
signal revived()

## Constructor.[br]
## [param _owner]: The Node that owns this component (must have "health" Stat property).[br]
## [param _iframe_duration]: Seconds of invulnerability after taking damage (0.0 = disabled).
func _init(_owner: Node, _iframe_duration: float = 0.0) -> void:
	owner = _owner
	iframe_duration = _iframe_duration
	
	# Retrieve health stat safely via new static helper
	health = Stat.get_stat(owner, "health")
	
	if health:
		health.value_changed.connect(_on_health_changed)
	else:
		push_error("HealthComponent: Owner must have a 'health' Stat property")


## Internal: Handle health stat changes (death detection).[br]
## [param new_value]: Current health value.
func _on_health_changed(new_value: float, _new_max: float, _old_value: float, _old_max: float) -> void:
	# Detect death once
	if new_value <= 0.0 and not is_dead:
		is_dead = true
		died.emit()
	# Optional: auto-revive if healed back from zero
	elif is_dead and new_value > 0.0:
		is_dead = false


## Process incoming damage request and return result.[br]
## [param request]: DamageRequest containing damage data from attacker.[br]
## [return]: DamageResult with actual damage dealt and flags.
func process_damage(request: DamageRequest) -> DamageResult:
	var result := DamageResult.new(request)
	
	# Check invulnerability (dead or iframes active)
	if is_dead or iframe_timer > 0.0:
		result.was_blocked = true
		damage_taken.emit(result)
		return result
	
	# Roll critical hit
	result.was_critical = randf() < clampf(request.crit_chance, 0.0, 1.0)
	var incoming := request.damage * (request.crit_damage if result.was_critical else 1.0)
	
	# Apply resistance by damage type (duck typing)
	var resist_stat := Stat.get_stat(owner, "resist_" + str(request.damage_type))
	if resist_stat:
		var resistance = resist_stat.get_value()
		incoming *= (1.0 - clampf(resistance, 0.0, 0.9))  # Max 90% resist
	
	# Apply damage
	result.actual_damage = incoming
	_apply_damage_to_health(incoming, result)
	
	# Start iframes
	if result.actual_damage > 0.0 and iframe_duration > 0.0:
		iframe_timer = iframe_duration
	
	damage_taken.emit(result)
	return result


## Internal: Apply damage to health stat.
func _apply_damage_to_health(amount: float, result: DamageResult) -> void:
	if health == null:
		return
	
	var old_health: float = health.get_value()
	var _actual_change: float = health.add_value(-amount)
	
	if health.get_value() <= 0.0:
		result.overkill = amount - old_health


## Heal by specified amount.
func heal(amount: float) -> float:
	if is_dead or health == null:
		return 0.0
	return health.add_value(amount)


## Update timers — call in owner's _process or _physics_process.
func update(delta: float) -> void:
	if iframe_timer > 0.0:
		iframe_timer -= delta


## Check invulnerability.
func is_invulnerable() -> bool:
	return iframe_timer > 0.0 or is_dead


## Getters for convenience.
func get_health() -> float:
	return health.get_value() if health else 0.0

func get_max_health() -> float:
	return health.get_max() if health else 0.0

func is_full_health() -> bool:
	return health.is_max() if health else false


## Revive the entity (resets death state; does NOT restore health).
func revive() -> void:
	is_dead = false
	iframe_timer = 0.0
	revived.emit()


## Forcefully kills the entity immediately.
func force_kill() -> void:
	if health:
		health.set_value(0.0)
