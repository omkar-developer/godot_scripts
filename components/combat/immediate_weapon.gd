class_name ImmediateWeapon
extends WeaponComponent

var damage_component: Object = null ## WeaponNode (provides create_damage_request)
var targeting_area: TargetingArea = null
var damage_all_targets: bool = false

signal damage_dealt(target: Node, result: DamageResult)
signal damage_failed(target: Node)

func _init(
	_owner: Object,
	_damage_component: Object, ## WeaponNode with create_damage_request()
	_targeting_area: TargetingArea,
	_base_fire_rate: float = 1.0,
	_attack_speed: float = 0.0,
	_attack_speed_scaling: float = 1.0
) -> void:
	super._init(_owner, _base_fire_rate, _attack_speed, _attack_speed_scaling)
	
	damage_component = _damage_component
	targeting_area = _targeting_area


func can_fire() -> bool:
	if not super.can_fire():
		return false
	
	if not damage_component or not targeting_area:
		return false
	
	return targeting_area.get_best_target() != null


func _execute_fire() -> void:
	if not damage_component or not targeting_area:
		push_warning("ImmediateWeapon: Missing damage_component or targeting_area")
		return
	
	if damage_all_targets:
		_damage_all_tracked_targets()
	else:
		_damage_single_target()


func _damage_single_target() -> void:
	var target = targeting_area.get_best_target()
	if not target:
		return
	
	var request: DamageRequest = damage_component.create_damage_request()
	var result := request.apply_to_target(target)

	if result:
		damage_dealt.emit(target, result)
	else:
		damage_failed.emit(target)


func _damage_all_tracked_targets() -> void:
	var targets = targeting_area.get_best_targets()

	for target in targets:
		if not is_instance_valid(target):
			continue
		
		var request: DamageRequest = damage_component.create_damage_request()
		var result := request.apply_to_target(target)

		if result:
			damage_dealt.emit(target, result)
		else:
			damage_failed.emit(target)


func set_damage_all_targets(all_targets: bool) -> void:
	damage_all_targets = all_targets


func is_damaging_all_targets() -> bool:
	return damage_all_targets
