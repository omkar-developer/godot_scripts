class_name WeaponComponent
extends RefCounted

var owner: Object = null
var auto_fire: bool = false
var cooldown_timer: float = 0.0

var base_fire_rate: float = 1.0
var attack_speed: float = 0.0
var attack_speed_scaling: float = 1.0

signal fired()
signal cooldown_ready()

func _init(
	_owner: Object = null,
	_base_fire_rate: float = 1.0,
	_attack_speed: float = 0.0,
	_attack_speed_scaling: float = 1.0
) -> void:
	owner = _owner
	base_fire_rate = _base_fire_rate
	attack_speed = _attack_speed
	attack_speed_scaling = _attack_speed_scaling

func get_cooldown() -> float:
	var fire_rate = base_fire_rate + (attack_speed * attack_speed_scaling)
	return maxf(0.05, 1.0 / maxf(0.01, fire_rate))

func can_fire() -> bool:
	return cooldown_timer >= get_cooldown()

func start_cooldown() -> void:
	cooldown_timer = 0.0

func update(delta: float) -> void:
	var cooldown = get_cooldown()
	
	if cooldown_timer < cooldown:
		cooldown_timer += delta
		
		if cooldown_timer >= cooldown:
			cooldown_ready.emit()
			
			if auto_fire:
				fire()

func fire() -> bool:
	if not can_fire():
		return false
	
	_execute_fire()
	start_cooldown()
	fired.emit()
	return true

func _execute_fire() -> void:
	pass

func reset_cooldown() -> void:
	cooldown_timer = get_cooldown()
	cooldown_ready.emit()

func get_remaining_cooldown() -> float:
	var remaining = get_cooldown() - cooldown_timer
	return maxf(0.0, remaining)

func get_cooldown_progress() -> float:
	var cooldown = get_cooldown()
	if cooldown <= 0.0:
		return 1.0
	return clampf(cooldown_timer / cooldown, 0.0, 1.0)

func set_auto_fire(enabled: bool) -> void:
	auto_fire = enabled

func is_auto_fire_enabled() -> bool:
	return auto_fire

func set_owner(_owner: Object) -> void:
	owner = _owner

func get_owner() -> Object:
	return owner

func is_owner_valid() -> bool:
	return is_instance_valid(owner)
