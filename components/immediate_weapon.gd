class_name ImmediateWeapon
extends WeaponComponent

## Immediate damage weapon that applies damage instantly to targets.[br]
##[br]
## This weapon type uses DamageComponent and TargetingComponent to apply damage[br]
## directly to selected targets without projectiles. Perfect for hitscan weapons,[br]
## melee attacks, AOE damage, beams, etc. Simply configure targeting and damage,[br]
## then fire() handles the rest.

## Damage component for creating and applying damage
var damage_component: DamageComponent = null

## Targeting component for selecting targets
var targeting_component: TargetingComponent = null

## Whether to damage all tracked targets or just the best one
var damage_all_targets: bool = false

## Emitted when damage is successfully applied to a target.[br]
## [param target]: The Node that was damaged.[br]
## [param result]: DamageResult containing actual damage dealt.
signal damage_dealt(target: Node, result: DamageResult)

## Emitted when damage fails (target has no process_damage method).[br]
## [param target]: The Node that couldn't be damaged.
signal damage_failed(target: Node)


## Constructor.[br]
## [param _owner]: The Object that owns this weapon.[br]
## [param _damage_component]: DamageComponent for damage handling.[br]
## [param _targeting_component]: TargetingComponent for target selection.[br]
## [param _base_fire_rate]: Fire rate (shots/sec) - can be float, Stat, or stat name.[br]
## [param _attack_speed]: Attack speed - can be float, Stat, or stat name (default: "attack_speed").[br]
## [param _attack_speed_scaling]: How much attack speed affects weapon (0.0-1.0).
func _init(
	_owner: Object,
	_damage_component: DamageComponent,
	_targeting_component: TargetingComponent,
	_base_fire_rate_param = 1.0,
	_attack_speed_param = "attack_speed",
	_attack_speed_scaling: float = 1.0
) -> void:
	super._init(_owner, _base_fire_rate_param, _attack_speed_param, _attack_speed_scaling)
	
	damage_component = _damage_component
	targeting_component = _targeting_component
	
	# Connect damage component signals
	if damage_component:
		damage_component.damage_applied.connect(_on_damage_applied)
		damage_component.damage_failed.connect(_on_damage_failed)


## Override: Execute weapon fire - applies damage to target(s).
func _execute_fire() -> void:
	if not damage_component or not targeting_component:
		push_warning("ImmediateWeapon: Missing damage_component or targeting_component")
		return
	
	if damage_all_targets:
		_damage_all_tracked_targets()
	else:
		_damage_single_target()


## Internal: Damage single best target.
func _damage_single_target() -> void:
	var target = targeting_component.get_best_target()
	if target:
		damage_component.apply_to(target)


## Internal: Damage all tracked targets.
func _damage_all_tracked_targets() -> void:
	var targets = targeting_component.get_best_targets()
	for target in targets:
		if is_instance_valid(target):
			damage_component.apply_to(target)


## Internal: Forward damage_applied signal.
func _on_damage_applied(target: Object, result: DamageResult) -> void:
	damage_dealt.emit(target, result)


## Internal: Forward damage_failed signal.
func _on_damage_failed(target: Object) -> void:
	damage_failed.emit(target)


## Configure whether to damage all tracked targets or just one.[br]
## [param all_targets]: true = damage all, false = damage best target only.
func set_damage_all_targets(all_targets: bool) -> void:
	damage_all_targets = all_targets


## Check if weapon damages all targets.[br]
## [return]: true if damaging all tracked targets.
func is_damaging_all_targets() -> bool:
	return damage_all_targets
