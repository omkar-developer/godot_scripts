class_name ImmediateWeapon
extends WeaponComponent

var damage_component: DamageComponent = null
var targeting_area: TargetingArea = null
var damage_all_targets: bool = false

signal damage_dealt(target: Node, result: DamageResult)
signal damage_failed(target: Node)

func _init(
	_owner: Object,
	_damage_component: DamageComponent,
	_targeting_area: TargetingArea,
	_base_fire_rate: float = 1.0,
	_attack_speed: float = 0.0,
	_attack_speed_scaling: float = 1.0
) -> void:
	super._init(_owner, _base_fire_rate, _attack_speed, _attack_speed_scaling)
	
	damage_component = _damage_component
	targeting_area = _targeting_area
	
	if damage_component:
		damage_component.damage_applied.connect(_on_damage_applied)
		damage_component.damage_failed.connect(_on_damage_failed)

func can_fire() -> bool:
	if not super.can_fire():
		return false
	
	if not damage_component or not targeting_area:
		return false
	
	# Check if we have valid targets
	var target = targeting_area.get_best_target()
	return target != null

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
	if target:
		damage_component.apply_to(target)

func _damage_all_tracked_targets() -> void:
	var targets = targeting_area.get_best_targets()
	for target in targets:
		if is_instance_valid(target):
			damage_component.apply_to(target)

func _on_damage_applied(target: Object, result: DamageResult) -> void:
	damage_dealt.emit(target, result)

func _on_damage_failed(target: Object) -> void:
	damage_failed.emit(target)

func set_damage_all_targets(all_targets: bool) -> void:
	damage_all_targets = all_targets

func is_damaging_all_targets() -> bool:
	return damage_all_targets
