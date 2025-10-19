@tool
class_name WeaponNode
extends Node2D

## Weapon properties
@export var weapon_id: String = ""
@export var auto_fire: bool = true
@export var enabled: bool = true
@export var spawn_point: Node2D = null
@export var spawn_offset: Vector2 = Vector2.ZERO

## Targeting
@export var use_global_targeting: bool = true
@export var needs_targeting: bool = true  # Some weapons don't need targeting (e.g., random fire)

## Stats (all editable in inspector)
@export var damage: Stat = Stat.new(10.0, true, 0.0, 10000.0)
@export var fire_rate: Stat = Stat.new(1.0, true, 0.01, 100.0)
@export var projectile_speed: Stat = Stat.new(300.0, true, 0.0, 10000.0)
@export var weapon_range: Stat = Stat.new(300.0, true, 0.0, 10000.0)
@export var crit_chance: Stat = Stat.new(0.0, true, 0.0, 1.0)
@export var crit_damage: Stat = Stat.new(1.5, true, 1.0, 10.0)

## Scaling (how much % of parent stat to add)
@export var damage_scaling: Stat = Stat.new(1.0, true, 0.0, 2.0)
@export var fire_rate_scaling: Stat = Stat.new(1.0, true, 0.0, 2.0)
@export var projectile_speed_scaling: Stat = Stat.new(1.0, true, 0.0, 2.0)
@export var range_scaling: Stat = Stat.new(1.0, true, 0.0, 2.0)
@export var crit_chance_scaling: Stat = Stat.new(1.0, true, 0.0, 2.0)
@export var crit_damage_scaling: Stat = Stat.new(1.0, true, 0.0, 2.0)

## Damage type
@export var damage_type: int = 0:
	set(value):
		damage_type = value
		if damage_component:
			damage_component.damage_type = value
	get:
		return damage_component.damage_type if damage_component else damage_type

## Component references
var damage_component: DamageComponent = null
var targeting_component: TargetingComponent = null
var local_targeting_component: TargetingComponent = null

## Local targeting area (if not using global)
var targeting_area: Area2D = null
var targeting_shape: CollisionShape2D = null

## Parent stats (from WeaponManager)
var parent_damage: Stat
var parent_fire_rate: Stat
var parent_projectile_speed: Stat
var parent_range: Stat
var parent_crit_chance: Stat
var parent_crit_damage: Stat

## Final calculated stats (auto-updated)
var final_damage: ScaledStat
var final_fire_rate: ScaledStat
var final_projectile_speed: ScaledStat
var final_range: ScaledStat
var final_crit_chance: ScaledStat
var final_crit_damage: ScaledStat

## Weapon component (override in subclasses)
var weapon_component: WeaponComponent = null

signal fired()

func _init() -> void:
	damage_component = DamageComponent.new(self)
	damage_component.damage_type = damage_type

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_get_parent_stats()
	_create_final_stats()
	_setup_targeting()
	_setup_weapon_component()
	_bind_stats_to_components()
	_connect_signals()

func _get_parent_stats() -> void:
	var parent = get_parent()
	if not parent:
		return
	
	parent_damage = Stat.get_stat(parent, "damage")
	parent_fire_rate = Stat.get_stat(parent, "fire_rate")
	parent_projectile_speed = Stat.get_stat(parent, "projectile_speed")
	parent_range = Stat.get_stat(parent, "range")
	parent_crit_chance = Stat.get_stat(parent, "crit_chance")
	parent_crit_damage = Stat.get_stat(parent, "crit_damage")

func _create_final_stats() -> void:
	# Create ScaledStat objects that auto-calculate base + (parent * scaling)
	final_damage = ScaledStat.new(damage, parent_damage, damage_scaling)
	final_fire_rate = ScaledStat.new(fire_rate, parent_fire_rate, fire_rate_scaling)
	final_projectile_speed = ScaledStat.new(projectile_speed, parent_projectile_speed, projectile_speed_scaling)
	final_range = ScaledStat.new(weapon_range, parent_range, range_scaling)
	final_crit_chance = ScaledStat.new(crit_chance, parent_crit_chance, crit_chance_scaling)
	final_crit_damage = ScaledStat.new(crit_damage, parent_crit_damage, crit_damage_scaling)

func _setup_damage_component() -> void:
	# Every weapon deals damage
	damage_component = DamageComponent.new(self)
	damage_component.damage_type = damage_type

func _setup_targeting() -> void:
	if use_global_targeting or not needs_targeting:
		return
	
	# Try to find existing targeting area in children
	targeting_area = get_node_or_null("TargetingArea")
	
	if not targeting_area:
		# Create targeting area programmatically
		targeting_area = Area2D.new()
		targeting_area.name = "TargetingArea"
		add_child(targeting_area)
		
		targeting_shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = final_range.get_value()
		targeting_shape.shape = circle
		targeting_area.add_child(targeting_shape)
	else:
		# Find existing shape
		targeting_shape = targeting_area.get_node_or_null("CollisionShape2D")
		if not targeting_shape:
			for child in targeting_area.get_children():
				if child is CollisionShape2D:
					targeting_shape = child
					break
	
	# Create local targeting component
	local_targeting_component = TargetingComponent.new(self, targeting_area)
	local_targeting_component.detection_range = final_range.get_value()

func _setup_weapon_component() -> void:
	# Override in subclasses to create specific weapon component
	# Example in ProjectileWeaponNode:
	# weapon_component = ProjectileWeapon.new(
	#     self,
	#     projectile_scene,
	#     damage_component,
	#     get_targeting(),
	#     final_fire_rate.get_value()
	# )
	# weapon_component.auto_fire = auto_fire
	pass

func _bind_stats_to_components() -> void:
	# Bind final stats to DamageComponent
	final_damage.bind_to_property(damage_component, "damage")
	final_crit_chance.bind_to_property(damage_component, "crit_chance")
	final_crit_damage.bind_to_property(damage_component, "crit_damage")
	
	# Bind to WeaponComponent (if created)
	if weapon_component:
		final_fire_rate.bind_to_property(weapon_component, "base_fire_rate")
	
	# Bind to local targeting component (if exists)
	if local_targeting_component:
		final_range.bind_to_property(local_targeting_component, "detection_range")
		
		# Also bind to collision shape radius
		if targeting_shape and targeting_shape.shape is CircleShape2D:
			final_range.bind_to_property(targeting_shape.shape, "radius")

func _connect_signals() -> void:
	# Connect weapon component signals
	if weapon_component:
		weapon_component.fired.connect(_on_weapon_fired)
		weapon_component.cooldown_ready.connect(_on_cooldown_ready)

func _on_weapon_fired() -> void:
	fired.emit()

func _on_cooldown_ready() -> void:
	# Override in subclasses if needed
	pass

func set_components(_damage: DamageComponent, _targeting: TargetingComponent) -> void:
	damage_component = _damage
	targeting_component = _targeting

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if not enabled or not weapon_component:
		return
	
	# Update local targeting if we have it
	if local_targeting_component:
		local_targeting_component.update(delta)
	
	weapon_component.update(delta)

func fire() -> bool:
	if not enabled or not weapon_component:
		return false
	
	return weapon_component.fire()

func get_targeting() -> TargetingComponent:
	return local_targeting_component if not use_global_targeting else targeting_component

func get_spawn_position() -> Vector2:
	if spawn_point and is_instance_valid(spawn_point):
		return spawn_point.global_position
	return global_position + spawn_offset.rotated(global_rotation)

func can_fire() -> bool:
	return weapon_component.can_fire() if weapon_component else false

func get_cooldown_progress() -> float:
	return weapon_component.get_cooldown_progress() if weapon_component else 0.0

## Get stat by name (for buffs/upgrades)
func get_stat(stat_name: String) -> Stat:
	match stat_name:
		"damage":
			return damage
		"fire_rate":
			return fire_rate
		"projectile_speed":
			return projectile_speed
		"range", "weapon_range":
			return weapon_range
		"crit_chance":
			return crit_chance
		"crit_damage":
			return crit_damage
		"damage_scaling":
			return damage_scaling
		"fire_rate_scaling":
			return fire_rate_scaling
		"projectile_speed_scaling":
			return projectile_speed_scaling
		"range_scaling":
			return range_scaling
		"crit_chance_scaling":
			return crit_chance_scaling
		"crit_damage_scaling":
			return crit_damage_scaling
		_:
			push_warning("WeaponNode: Unknown stat: " + stat_name)
			return null

## Get final calculated stat value
func get_final_stat(stat_name: String) -> float:
	match stat_name:
		"damage":
			return final_damage.get_value()
		"fire_rate":
			return final_fire_rate.get_value()
		"projectile_speed":
			return final_projectile_speed.get_value()
		"range", "weapon_range":
			return final_range.get_value()
		"crit_chance":
			return final_crit_chance.get_value()
		"crit_damage":
			return final_crit_damage.get_value()
		_:
			push_warning("WeaponNode: Unknown final stat: " + stat_name)
			return 0.0
