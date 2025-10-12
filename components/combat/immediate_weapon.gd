class_name ImmediateWeapon
extends WeaponComponent

var damage_component: DamageComponent = null
var targeting_component: TargetingComponent = null
var damage_all_targets: bool = false

signal damage_dealt(target: Node, result: DamageResult)
signal damage_failed(target: Node)

func _init(
	_owner: Object,
	_damage_component: DamageComponent,
	_targeting_component: TargetingComponent,
	_base_fire_rate: float = 1.0,
	_attack_speed: float = 0.0,
	_attack_speed_scaling: float = 1.0
) -> void:
	super._init(_owner, _base_fire_rate, _attack_speed, _attack_speed_scaling)
	
	damage_component = _damage_component
	targeting_component = _targeting_component
	
	if damage_component:
		damage_component.damage_applied.connect(_on_damage_applied)
		damage_component.damage_failed.connect(_on_damage_failed)

func _execute_fire() -> void:
	if not damage_component or not targeting_component:
		push_warning("ImmediateWeapon: Missing damage_component or targeting_component")
		return
	
	if damage_all_targets:
		_damage_all_tracked_targets()
	else:
		_damage_single_target()

func _damage_single_target() -> void:
	var target = targeting_component.get_best_target()
	if target:
		damage_component.apply_to(target)

func _damage_all_tracked_targets() -> void:
	var targets = targeting_component.get_best_targets()
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
