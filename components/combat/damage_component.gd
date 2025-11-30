class_name DamageComponent
extends RefCounted

var owner: Object = null

signal damage_applied(target: Object, result: DamageResult)
signal damage_failed(target: Object)


func _init(_owner: Object = null) -> void:
	owner = _owner

func get_owner() -> Object:
	return owner

func create_request(
	_damage: float,
	_type: int,
	_crit_chance: float,
	_crit_damage: float,
	_knockback: Vector2
) -> DamageRequest:
	var request := DamageRequest.new(owner, self, _damage, _type)
	request.crit_chance = _crit_chance
	request.crit_damage = _crit_damage
	request.knockback = _knockback
	return request


func apply_request_to(target: Object, request: DamageRequest) -> DamageResult:
	var health_comp: HealthComponent = target.get("health_component") as HealthComponent

	var result: DamageResult = null

	if health_comp:
		result = health_comp.process_damage(request)
	elif target.has_method("process_damage"):
		result = target.process_damage(request)
	else:
		damage_failed.emit(target)
		return null

	damage_applied.emit(target, result)
	return result
