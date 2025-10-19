class_name ImmediateWeaponNode
extends WeaponNode

## Immediate weapon specific properties
@export var damage_all_in_range: bool = false
@export var visual_effect_scene: PackedScene = null
@export var spawn_visual_on_damage: bool = true  # Control whether to spawn visuals

## Additional local stats for immediate weapons
@export var local_target_count_stat: Stat

## Local stat base for target count (if stat not provided)
@export var local_target_count_base: float = 1.0

## Target count global scaling
@export_range(0.0, 2.0, 0.1) var target_count_global_scaling: float = 0.0

## Target count weapon stat calculator
var target_count_weapon_stat: WeaponStat

## Final calculated target count
var final_target_count: int = 1

## Reference to the immediate weapon component
var _immediate_weapon: ImmediateWeapon = null

signal damage_dealt(target: Node, result: DamageResult)
signal damage_failed(target: Node)
signal visual_effect_spawned(effect: Node)

func _ready() -> void:
	_initialize_target_count_stat()
	super._ready()

func _initialize_target_count_stat() -> void:
	if not local_target_count_stat:
		local_target_count_stat = Stat.new(local_target_count_base, true, 1.0, 100.0)
	
	# Try to find global target count stat
	var global_target_stat: Stat = null
	if get_parent():
		global_target_stat = Stat.get_stat(get_parent(), "target_count", false)
	
	target_count_weapon_stat = WeaponStat.new(local_target_count_stat, global_target_stat, target_count_global_scaling)
	target_count_weapon_stat.value_changed.connect(_on_weapon_stat_changed)

func _setup_weapon_component() -> void:
	if not _damage_component:
		push_warning("ImmediateWeaponNode: No damage_component available for weapon: " + weapon_id)
		return
	
	var targeting = get_targeting_component()
	
	if not targeting:
		push_warning("ImmediateWeaponNode: No targeting_component available for weapon: " + weapon_id)
		return
	
	_immediate_weapon = ImmediateWeapon.new(
		self,
		_damage_component,
		targeting,
		final_fire_rate
	)
	
	_weapon_component = _immediate_weapon
	_weapon_component.set_auto_fire(auto_fire)
	
	# Connect signals
	_immediate_weapon.damage_dealt.connect(_on_damage_dealt)
	_immediate_weapon.damage_failed.connect(_on_damage_failed)
	
	# Apply initial properties
	_apply_immediate_properties()

func _apply_specific_stats() -> void:
	if not _immediate_weapon:
		return
	
	# Calculate final target count
	final_target_count = int(target_count_weapon_stat.get_final_value())
	final_target_count = maxi(1, final_target_count)
	
	_apply_immediate_properties()

func _apply_immediate_properties() -> void:
	if not _immediate_weapon:
		return
	
	# Enable damage all if configured or if target count > 1
	_immediate_weapon.set_damage_all_targets(damage_all_in_range or final_target_count > 1)

func _on_damage_dealt(target: Node, result: DamageResult) -> void:
	# Spawn visual effect if configured (but not for persistent effects like lasers)
	if spawn_visual_on_damage and visual_effect_scene:
		_spawn_visual_effect(target)
	
	damage_dealt.emit(target, result)

func _on_damage_failed(target: Node) -> void:
	damage_failed.emit(target)

func _spawn_visual_effect(target: Node) -> void:
	if not visual_effect_scene:
		return
	
	var effect = visual_effect_scene.instantiate()
	if not effect:
		push_warning("ImmediateWeaponNode: Failed to instantiate visual effect for weapon: " + weapon_id)
		return
	
	# Position effect
	if effect is Node2D and target is Node2D:
		effect.global_position = target.global_position
	
	# Setup effect properties for different effect types
	if "start_position" in effect:
		effect.start_position = global_position
	
	if "end_position" in effect and target is Node2D:
		effect.end_position = target.global_position
	
	if "target" in effect:
		effect.target = target
	
	if "source" in effect:
		effect.source = self
	
	# Add to scene
	var parent = get_parent()
	if parent:
		parent.add_child(effect)
	else:
		get_tree().root.add_child(effect)
	
	visual_effect_spawned.emit(effect)

## Override get_stat to include target_count
func get_stat(stat_name: String) -> Stat:
	if stat_name == "target_count":
		return local_target_count_stat
	return super.get_stat(stat_name)

## Setters for runtime configuration
func set_damage_all_in_range(all: bool) -> void:
	damage_all_in_range = all
	_apply_immediate_properties()

func set_visual_effect_scene(scene: PackedScene) -> void:
	visual_effect_scene = scene

func set_spawn_visual_on_damage(_enabled: bool) -> void:
	spawn_visual_on_damage = _enabled
