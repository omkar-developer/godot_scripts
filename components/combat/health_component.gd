class_name HealthComponent
extends RefCounted

var owner: Object = null
var damage_calculator: DamageCalculator = null

var current_health: float = 100.0
var max_health: float = 100.0
var current_shield: float = 0.0
var max_shield: float = 0.0
var damage_reduction: float = 0.0
var damage_multiplier: float = 1.0
var resistances: Dictionary = {}

var is_dead: bool = false
var iframe_timer: float = 0.0
var iframe_duration: float = 0.0
var iframe_enabled: bool = true
var shield_enabled: bool = false
var max_damage_per_hit: float = 0.0
var prevent_death_once: bool = false
var _death_prevented: bool = false
var invulnerable: bool = false
var immune_damage_types: Array[int] = []

# Stat binding control
var _health_stat_bound: bool = false
var _shield_stat_bound: bool = false

signal damage_taken(result: DamageResult)
signal died()
signal revived()
signal iframe_started(duration: float)
signal iframe_ended()
signal critical_hit_taken(result: DamageResult)
signal damage_blocked(request: DamageRequest)
signal healed(amount: float)
signal shield_damaged(amount: float)
signal shield_broken(overkill: float)
signal shield_restored(amount: float)
signal death_prevented(request: DamageRequest)
signal damage_immunity_triggered(damage_type: int)

# Two-way binding signals for Stat integration
signal health_value_set(value: float)
signal health_value_added(delta: float)
signal max_health_value_set(value: float)
signal shield_value_set(value: float)
signal shield_value_added(delta: float)
signal max_shield_value_set(value: float)

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
	owner = _owner
	iframe_duration = _iframe_duration
	shield_enabled = _shield_enabled
	max_damage_per_hit = _max_damage_per_hit
	prevent_death_once = _prevent_death_once
	immune_damage_types = _immune_damage_types.duplicate()
	
	max_health = _max_health
	current_health = _max_health
	max_shield = _max_shield
	current_shield = _max_shield if _shield_enabled else 0.0

func process_damage(request: DamageRequest) -> DamageResult:
	var result = DamageResult.new(request)
	
	if invulnerable:
		result.was_blocked = true
		damage_blocked.emit(request)
		damage_taken.emit(result)
		return result
	
	if immune_damage_types.has(request.damage_type):
		result.was_blocked = true
		damage_immunity_triggered.emit(request.damage_type)
		damage_taken.emit(result)
		return result
	
	if is_dead or (iframe_enabled and iframe_timer > 0.0):
		result.was_blocked = true
		damage_blocked.emit(request)
		damage_taken.emit(result)
		return result
	
	var incoming: float
	if damage_calculator:
		incoming = damage_calculator.calculate_damage(request, self, result)
	else:
		result.was_critical = randf() < clampf(request.crit_chance, 0.0, 1.0)
		incoming = request.damage * (request.crit_damage if result.was_critical else 1.0)
		
		var resistance = resistances.get(request.damage_type, 0.0)
		incoming *= (1.0 - clampf(resistance, 0.0, 0.9))
		
		incoming = maxf(0.0, incoming - damage_reduction)
		incoming *= damage_multiplier
		
		if max_damage_per_hit > 0.0:
			incoming = minf(incoming, max_damage_per_hit)
	
	_apply_damage(incoming, result)
	
	if result.actual_damage > 0.0 and iframe_enabled and iframe_duration > 0.0:
		iframe_timer = iframe_duration
		iframe_started.emit(iframe_duration)
	
	if result.was_critical:
		critical_hit_taken.emit(result)
	
	damage_taken.emit(result)
	return result

func _apply_damage(amount: float, result: DamageResult) -> void:
	var remaining_damage = amount
	
	if shield_enabled:
		var shield_value = current_shield
		
		if shield_value > 0.0:
			var shield_absorbed = minf(remaining_damage, shield_value)
			
			if _shield_stat_bound:
				# Let stat handle the change
				shield_value_added.emit(-shield_absorbed)
			else:
				# Handle locally with clamping
				current_shield = clampf(current_shield - shield_absorbed, 0.0, max_shield)
			
			result.shield_damaged = shield_absorbed
			shield_damaged.emit(shield_absorbed)
			remaining_damage -= shield_absorbed
			
			if current_shield <= 0.0 and remaining_damage > 0.0:
				shield_broken.emit(remaining_damage)
	
	if remaining_damage > 0.0:
		var old_health = current_health
		
		if prevent_death_once and not _death_prevented:
			var would_die = (old_health - remaining_damage) <= 0.0
			
			if would_die:
				remaining_damage = old_health - 1.0
				_death_prevented = true
				death_prevented.emit(result.request)
		
		if _health_stat_bound:
			# Let stat handle the change
			health_value_added.emit(-remaining_damage)
		else:
			# Handle locally with clamping
			current_health = clampf(current_health - remaining_damage, 0.0, max_health)
		
		result.actual_damage = remaining_damage
		
		var new_health = current_health if not _health_stat_bound else (old_health - remaining_damage)
		if new_health <= 0.0:
			result.overkill = remaining_damage - old_health
		
		if current_health <= 0.0 and not is_dead:
			is_dead = true
			died.emit()
	else:
		result.actual_damage = 0.0

func heal(amount: float) -> float:
	if is_dead or amount <= 0.0:
		return 0.0
	
	var old_health = current_health
	
	if _health_stat_bound:
		# Let stat handle the change
		health_value_added.emit(amount)
		# Actual healed will be calculated after stat updates current_health
		return amount  # Return requested amount, actual will be in signal

	# Handle locally with clamping
	current_health = clampf(current_health + amount, 0.0, max_health)
	var actual_healed = current_health - old_health
	
	if actual_healed > 0.0:
		healed.emit(actual_healed)
		
		if is_dead and current_health > 0.0:
			is_dead = false
	
	return actual_healed

func restore_shield(amount: float) -> float:
	if not shield_enabled or amount <= 0.0:
		return 0.0
	
	var old_shield = current_shield
	
	if _shield_stat_bound:
		# Let stat handle the change
		shield_value_added.emit(amount)
		return amount  # Return requested amount

	# Handle locally with clamping
	current_shield = clampf(current_shield + amount, 0.0, max_shield)
	var actual_restored = current_shield - old_shield
	
	if actual_restored > 0.0:
		shield_restored.emit(actual_restored)
	
	return actual_restored

func update(delta: float) -> void:
	if iframe_enabled and iframe_timer > 0.0:
		var was_active = iframe_timer > 0.0
		iframe_timer -= delta
		
		if was_active and iframe_timer <= 0.0:
			iframe_ended.emit()

func is_invulnerable() -> bool:
	return invulnerable or is_dead or (iframe_enabled and iframe_timer > 0.0)

func get_health() -> float:
	return current_health

func get_max_health() -> float:
	return max_health

func get_shield() -> float:
	return current_shield

func get_max_shield() -> float:
	return max_shield

func is_full_health() -> bool:
	return current_health >= max_health

func is_full_shield() -> bool:
	if not shield_enabled:
		return false
	return current_shield >= max_shield

func get_iframe_fraction() -> float:
	if not iframe_enabled or iframe_duration <= 0.0:
		return 0.0
	return clampf(iframe_timer / iframe_duration, 0.0, 1.0)

func get_iframe_remaining() -> float:
	return maxf(0.0, iframe_timer) if iframe_enabled else 0.0

func revive() -> void:
	is_dead = false
	iframe_timer = 0.0
	_death_prevented = false
	revived.emit()

func force_kill() -> void:
	if _health_stat_bound:
		health_value_set.emit(0.0)
	else:
		current_health = 0.0
	
	if not is_dead:
		is_dead = true
		died.emit()

func start_iframe(duration: float) -> void:
	if iframe_enabled and duration > 0.0:
		iframe_timer = duration
		iframe_started.emit(duration)

func end_iframe() -> void:
	if iframe_enabled and iframe_timer > 0.0:
		iframe_timer = 0.0
		iframe_ended.emit()

func set_iframe_enabled(enabled: bool) -> void:
	var was_enabled = iframe_enabled
	iframe_enabled = enabled
	
	if was_enabled and not enabled and iframe_timer > 0.0:
		iframe_timer = 0.0
		iframe_ended.emit()

func set_shield_enabled(enabled: bool) -> void:
	shield_enabled = enabled

func add_damage_immunity(damage_type: int) -> void:
	if not immune_damage_types.has(damage_type):
		immune_damage_types.append(damage_type)

func remove_damage_immunity(damage_type: int) -> void:
	immune_damage_types.erase(damage_type)

func is_immune_to(damage_type: int) -> bool:
	return immune_damage_types.has(damage_type)

func reset_death_prevention() -> void:
	_death_prevented = false

func was_death_prevented() -> bool:
	return _death_prevented

func set_damage_calculator(calculator: DamageCalculator) -> void:
	damage_calculator = calculator

func get_damage_calculator() -> DamageCalculator:
	return damage_calculator

func set_resistance(damage_type: int, resistance: float) -> void:
	resistances[damage_type] = clampf(resistance, 0.0, 1.0)

func get_resistance(damage_type: int) -> float:
	return resistances.get(damage_type, 0.0)

func remove_resistance(damage_type: int) -> void:
	resistances.erase(damage_type)

func set_max_health(new_max: float, adjust_current: bool = false) -> void:
	if _health_stat_bound:
		max_health_value_set.emit(new_max)
		if adjust_current and max_health > 0.0:
			var ratio = current_health / max_health
			health_value_set.emit(new_max * ratio)
	else:
		if adjust_current and max_health > 0.0:
			var ratio = current_health / max_health
			max_health = new_max
			current_health = new_max * ratio
		else:
			max_health = new_max
			current_health = minf(current_health, max_health)

func set_max_shield(new_max: float, adjust_current: bool = false) -> void:
	if _shield_stat_bound:
		max_shield_value_set.emit(new_max)
		if adjust_current and max_shield > 0.0:
			var ratio = current_shield / max_shield
			shield_value_set.emit(new_max * ratio)
	else:
		if adjust_current and max_shield > 0.0:
			var ratio = current_shield / max_shield
			max_shield = new_max
			current_shield = new_max * ratio
		else:
			max_shield = new_max
			current_shield = minf(current_shield, max_shield)

func set_health(value: float) -> void:
	if _health_stat_bound:
		health_value_set.emit(value)
	else:
		current_health = clampf(value, 0.0, max_health)

func set_shield(value: float) -> void:
	if _shield_stat_bound:
		shield_value_set.emit(value)
	else:
		current_shield = clampf(value, 0.0, max_shield)

# Stat binding helpers
func bind_health_stat(stat) -> void:
	if not stat.has_method("bind_to_property"):
		push_error("bind_health_stat: object doesn't have bind_to_property method")
		return
	
	_health_stat_bound = true
	stat.bind_to_property(self, "current_health", "health_value_set", "health_value_added")
	stat.bind_max_to_property(self, "max_health", "max_health_value_set")

func bind_shield_stat(stat) -> void:
	if not stat.has_method("bind_to_property"):
		push_error("bind_shield_stat: object doesn't have bind_to_property method")
		return
	
	_shield_stat_bound = true
	stat.bind_to_property(self, "current_shield", "shield_value_set", "shield_value_added")
	stat.bind_max_to_property(self, "max_shield", "max_shield_value_set", "max_shield_value_added")

func unbind_health_stat() -> void:
	_health_stat_bound = false

func unbind_shield_stat() -> void:
	_shield_stat_bound = false

func is_health_stat_bound() -> bool:
	return _health_stat_bound

func is_shield_stat_bound() -> bool:
	return _shield_stat_bound
