class_name DamageRequest
extends RefCounted

var owner: Object = null
var damage_component_ref: WeakRef = null

var damage: float = 0.0
var damage_type: int = 0
var crit_chance: float = 0.0
var crit_damage: float = 1.5
var knockback: Vector2 = Vector2.ZERO


func _init(
	_owner: Object = null,
	_damage_component: DamageComponent = null,
	_damage: float = 0.0,
	_type: int = 0
) -> void:
	owner = _owner
	damage = _damage
	damage_type = _type

	if _damage_component:
		damage_component_ref = weakref(_damage_component)


func get_damage_component() -> DamageComponent:
	if not damage_component_ref:
		return null

	var ref = damage_component_ref.get_ref()
	if ref is DamageComponent:
		return ref

	return null

func get_owner() -> Object:
	return owner

func apply_to_target(target: Object) -> DamageResult:
	var dmg_comp := get_damage_component()

	# Preferred path: go through DamageComponent for signals & analytics
	if dmg_comp:
		return dmg_comp.apply_request_to(target, self)

	# Fallback: direct health processing
	var health_comp: HealthComponent = target.get("health_component") as HealthComponent
	if health_comp:
		return health_comp.process_damage(self)

	if target.has_method("process_damage"):
		return target.process_damage(self)

	return null
