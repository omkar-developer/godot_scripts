class_name WeaponManager
extends Node2D

## Stats
var damage: Stat
var fire_rate: Stat
var projectile_speed: Stat
var global_range: Stat

## Component references (from parent)
var damage_component: DamageComponent = null
var targeting_component: TargetingComponent = null

func _init(
	_damage: float = 10.0,
	_fire_rate: float = 1.0,
	_projectile_speed: float = 300.0,
	_range: float = 300.0
) -> void:
	damage = Stat.new(_damage, true, 0.0, 10000.0)
	fire_rate = Stat.new(_fire_rate, true, 0.01, 100.0)
	projectile_speed = Stat.new(_projectile_speed, true, 0.0, 10000.0)
	global_range = Stat.new(_range, true, 0.0, 10000.0)

func _enter_tree() -> void:
	_get_components_from_parent()
	_pass_components_to_weapons()

func _get_components_from_parent() -> void:
	var parent = get_parent()
	if not parent:
		return
	
	damage_component = parent.get("damage_component") as DamageComponent
	targeting_component = parent.get("targeting_component") as TargetingComponent

func _pass_components_to_weapons() -> void:
	for child in get_children():
		if child is WeaponNode:
			child.set_components(damage_component, targeting_component)

## Add weapon as child
func add_weapon(weapon: WeaponNode) -> void:
	if not weapon:
		push_warning("WeaponManager: Cannot add null weapon")
		return
	add_child(weapon)
	weapon.set_components(damage_component, targeting_component)

## Remove weapon by reference
func remove_weapon(weapon: WeaponNode) -> void:
	if weapon and weapon.get_parent() == self:
		remove_child(weapon)

## Get stat by name
func get_stat(stat_name: String) -> Stat:
	match stat_name:
		"damage":
			return damage
		"fire_rate":
			return fire_rate
		"projectile_speed":
			return projectile_speed
		"range":
			return global_range
		_:
			push_warning("WeaponManager: Unknown stat: " + stat_name)
			return null

## Find weapon by ID
func find_weapon(weapon_id: String) -> WeaponNode:
	for child in get_children():
		if child is WeaponNode and child.weapon_id == weapon_id:
			return child
	return null

## Find weapons by type
func find_weapons_by_type(weapon_type: String) -> Array[WeaponNode]:
	var result: Array[WeaponNode] = []
	for child in get_children():
		if child is WeaponNode and child.get("weapon_type") == weapon_type:
			result.append(child)
	return result

## Get all weapons
func get_weapons() -> Array[WeaponNode]:
	var result: Array[WeaponNode] = []
	for child in get_children():
		if child is WeaponNode:
			result.append(child)
	return result

## Set component references
func set_components(_damage_component: DamageComponent, _targeting_component: TargetingComponent) -> void:
	damage_component = _damage_component
	targeting_component = _targeting_component
	_pass_components_to_weapons()
