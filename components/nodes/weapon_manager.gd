@tool
@icon("res://scripts/icons/weapon.svg")
class_name WeaponManager
extends Node2D


## =========================
## GLOBAL STATS (INSPECTOR)
## =========================
## These are created locally by default.
## At runtime, they can be overridden by matching stats on the parent.

@export var damage: Stat = Stat.new(10.0, true, 0.0, 10000.0)
@export var fire_rate: Stat = Stat.new(1.0, true, 0.01, 100.0)
@export var projectile_speed: Stat = Stat.new(300.0, true, 0.0, 10000.0)
@export var weapon_range: Stat = Stat.new(300.0, true, 0.0, 10000.0)

## Optional future stats (safe even if unused)
@export var crit_chance: Stat = Stat.new(0.0, true, 0.0, 1.0)
@export var crit_damage: Stat = Stat.new(1.5, true, 1.0, 10.0)

## If true, runtime will attempt to pull matching stats from the parent.
@export var override_parent_stats: bool = true


## =========================
## COMPONENT REFERENCES
## =========================

var damage_component: DamageComponent = null
var targeting_area: TargetingArea = null


## =========================
## LIFECYCLE (SAFE WITH @tool)
## =========================

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	_override_stats_from_parent()
	_get_components_from_parent()
	_pass_components_to_weapons()
	
## =========================
## STAT OVERRIDE (RUNTIME ONLY)
## =========================

func _override_stats_from_parent() -> void:
	if not override_parent_stats:
		return

	var parent := get_parent()
	if not parent:
		return

	var s: Stat

	s = Stat.get_stat(parent, "damage")
	if s:
		damage = s

	s = Stat.get_stat(parent, "fire_rate")
	if s:
		fire_rate = s

	s = Stat.get_stat(parent, "projectile_speed")
	if s:
		projectile_speed = s

	s = Stat.get_stat(parent, "weapon_range")
	if s:
		weapon_range = s

	s = Stat.get_stat(parent, "range")
	if s:
		weapon_range = s

	s = Stat.get_stat(parent, "crit_chance")
	if s:
		crit_chance = s

	s = Stat.get_stat(parent, "crit_damage")
	if s:
		crit_damage = s


## =========================
## COMPONENT ROUTING
## =========================

func _get_components_from_parent() -> void:
	var parent = get_parent()
	if not parent:
		return

	targeting_area = parent.get("targeting_area") as TargetingArea
	damage_component = parent.get("damage_component") as DamageComponent

func _pass_components_to_weapons() -> void:
	for child in get_children():
		if child is WeaponNode:
			child.set_components(damage_component, targeting_area)


## =========================
## WEAPON MANAGEMENT
## =========================

func add_weapon(weapon: WeaponNode) -> void:
	if not weapon:
		push_warning("WeaponManager: Cannot add null weapon")
		return

	add_child(weapon)
	weapon.set_components(damage_component, targeting_area)


func remove_weapon(weapon: WeaponNode) -> void:
	if weapon and weapon.get_parent() == self:
		remove_child(weapon)


func get_weapons() -> Array[WeaponNode]:
	var result: Array[WeaponNode] = []
	for child in get_children():
		if child is WeaponNode:
			result.append(child)
	return result


func find_weapon(weapon_id: String) -> WeaponNode:
	for child in get_children():
		if child is WeaponNode and child.weapon_id == weapon_id:
			return child
	return null


## =========================
## FIRING CONTROL HELPERS
## =========================

func fire_weapon(weapon_id: String) -> void:
	var weapon := find_weapon(weapon_id)
	if not weapon:
		push_warning("WeaponManager: Weapon not found: " + weapon_id)
		return

	if weapon.enabled:
		weapon.fire()


func stop_weapon(weapon_id: String) -> void:
	var weapon := find_weapon(weapon_id)
	if weapon:
		weapon.cancel_continuous_fire()


func fire_all() -> void:
	for weapon in get_weapons():
		if weapon.enabled:
			weapon.fire()


func stop_all() -> void:
	for weapon in get_weapons():
		weapon.cancel_continuous_fire()


func enable_weapon(weapon_id: String) -> void:
	var weapon := find_weapon(weapon_id)
	if weapon:
		weapon.enabled = true


func disable_weapon(weapon_id: String) -> void:
	var weapon := find_weapon(weapon_id)
	if weapon:
		weapon.enabled = false


## =========================
## STAT ACCESS FOR BUFF SYSTEM
## =========================

## Stat resolver for global + weapon-specific stats.
func get_stat(stat_name: String) -> Stat:
	# 1. Try global stats on the manager itself
	match stat_name:
		"damage":
			return damage
		"fire_rate":
			return fire_rate
		"projectile_speed":
			return projectile_speed
		"weapon_range", "range":
			return weapon_range
		"crit_chance":
			return crit_chance
		"crit_damage":
			return crit_damage
		_:
			pass

	# 2. Ask all weapons if any of them can resolve this stat
	for child in get_children():
		if child is WeaponNode:
			var weapon := child as WeaponNode
			var stat := weapon.get_stat(stat_name)
			if stat != null:
				return stat

	# 3. Not found anywhere
	push_warning("WeaponManager: Unknown stat: " + stat_name)
	return null


## =========================
## MANUAL COMPONENT OVERRIDE
## =========================

func set_components(_damage_component: DamageComponent, _targeting_component: TargetingArea) -> void:
	damage_component = _damage_component
	targeting_area = _targeting_component
	_pass_components_to_weapons()
