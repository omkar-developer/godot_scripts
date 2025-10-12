class_name DamageComponent
extends RefCounted

var owner: Object = null
var damage: float = 10.0
var damage_type: int = 0
var crit_chance: float = 0.0
var crit_damage: float = 1.5
var knockback: Vector2 = Vector2.ZERO

signal damage_applied(target: Object, result: DamageResult)
signal damage_failed(target: Object)

func _init(_owner: Object = null) -> void:
	owner = _owner

func create_request() -> DamageRequest:
	var valid_owner = get_owner()
	
	var request = DamageRequest.new(valid_owner, damage, damage_type)
	request.crit_chance = crit_chance
	request.crit_damage = crit_damage
	request.knockback = knockback
	return request

func apply_to(target: Object) -> DamageResult:
	if not is_instance_valid(target) or not target.has_method("process_damage"):
		damage_failed.emit(target)
		return null
	
	var request = create_request()
	var result: DamageResult = target.process_damage(request)
	
	if result:
		damage_applied.emit(target, result)
	
	return result

func set_owner(_owner: Object) -> void:
	owner = _owner

func get_owner() -> Object:
	return owner

func is_owner_valid() -> bool:
	return get_owner() != null

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
