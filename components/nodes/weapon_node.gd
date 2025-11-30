@tool
@icon("res://scripts/icons/weapon.svg")
class_name WeaponNode
extends Node2D

## =========================
## CORE WEAPON PROPERTIES
## =========================

## Unique string ID used for referencing this weapon in upgrades, saves, AI logic, etc.
@export var weapon_id: String = ""

## If true, the weapon will automatically fire whenever its cooldown allows.[br]
## Typical for enemies, turrets, and auto-weapons.
@export var auto_fire: bool = true

## Master enable/disable flag for this weapon. [br]
## When false, the weapon will never fire even if triggered.
@export var enabled: bool = true


## =========================
## DAMAGE CONFIGURATION
## =========================

## Logical damage type ID (used by DamageComponent for resistances, elements, armor, etc.)
@export var damage_type: int = 0:
	set(value):
		damage_type = value
		if damage_component:
			damage_component.damage_type = value
	get:
		return damage_component.damage_type if damage_component else damage_type


## =========================
## SPAWN POSITIONING
## =========================

## Optional Node2D used as the exact spawn origin for projectiles. [br]
## If null, the weapon owner position is used instead.
@export var spawn_point: Node2D = null

## Local offset applied to the spawn position.[br]
## Used for muzzle offsets, side cannons, dual barrels, etc.
@export var spawn_offset: Vector2 = Vector2.ZERO


## =========================
## CONTINUOUS FIRE SETTINGS
## =========================
@export_group("Continuous Fire")

## Defines whether the weapon fires once (SINGLE) or repeatedly (CONTINUOUS).
@export var fire_mode: WeaponComponent.FireMode = WeaponComponent.FireMode.SINGLE

## Defines how a CONTINUOUS weapon stops firing:[br]
## - SHOT_COUNT: after max_shots[br]
## - DURATION: after max_duration[br]
## - MANUAL: only on external cancel[br]
@export var stop_condition: WeaponComponent.StopCondition = WeaponComponent.StopCondition.SHOT_COUNT

## Time between individual shots inside a CONTINUOUS burst (NOT the cooldown).
@export var fire_interval: float = 0.1

## Maximum number of shots allowed in a SHOT_COUNT burst.
@export var max_shots: int = 3

## Maximum time (seconds) the weapon is allowed to fire in DURATION mode.
@export var max_duration: float = 1.0

## If true, the weapon fires immediately when a burst starts.[br]
## If false, it waits for the first fire_interval before shooting.
@export var fire_on_start: bool = true

## If true, cooldown starts after the burst ends.[br]
## If false, cooldown can run during the burst.
@export var cooldown_after_stop: bool = true


## =========================
## TARGETING SETTINGS
## =========================
@export_group("Targeting")

## If true, this weapon uses the owner's global TargetingComponent.[br]
## If false, the weapon expects its own tracking data.
@export var use_global_targeting: bool = true

## If true, the weapon refuses to fire unless a valid target exists.[br]
## If false, free-fire weapons can shoot without enemies.[br]
@export var needs_targeting: bool = true  # e.g. random sprays, traps, bullet walls

@export_flags_2d_physics var target_collision_layer: int = 1 << 3: ## does not work on child/global targeting area
	set(v):
		target_collision_layer = v
		if local_targeting_area:
			local_targeting_area.collision_layer = v
			
@export_flags_2d_physics var target_collision_mask: int = 2: ## does not work on child/global targeting area
	set(v):
		target_collision_mask = v
		if local_targeting_area:
			local_targeting_area.collision_mask = v

## =========================
## BASE STATS
## =========================
@export_group("Stats")

## Base damage per hit before crits and scaling.
@export var damage: Stat = Stat.new(10.0, true, 0.0, 10000.0)

## How many attack cycles per second this weapon can attempt.
## Final cooldown is derived from this.
@export var fire_rate: Stat = Stat.new(1.0, true, 0.01, 100.0)

## Speed applied to projectiles.
@export var projectile_speed: Stat = Stat.new(300.0, true, 0.0, 10000.0)

## Maximum targeting distance for this weapon.
@export var weapon_range: Stat = Stat.new(300.0, true, 0.0, 10000.0)

## Chance (0–1) that an attack becomes a critical hit.
@export var crit_chance: Stat = Stat.new(0.0, true, 0.0, 1.0)

## Damage multiplier applied when a critical hit occurs.
@export var crit_damage: Stat = Stat.new(1.5, true, 1.0, 10.0)


## =========================
## STAT SCALING MULTIPLIERS
## =========================
@export_subgroup("Scaling")

## Multiplier applied to the base damage stat.
@export var damage_scaling: Stat = Stat.new(1.0, true, 0.0, 2.0)

## Multiplier applied to the fire rate stat.
@export var fire_rate_scaling: Stat = Stat.new(1.0, true, 0.0, 2.0)

## Multiplier applied to projectile speed.
@export var projectile_speed_scaling: Stat = Stat.new(1.0, true, 0.0, 2.0)

## Multiplier applied to weapon range.
@export var range_scaling: Stat = Stat.new(1.0, true, 0.0, 2.0)

## Multiplier applied to critical hit chance.
@export var crit_chance_scaling: Stat = Stat.new(1.0, true, 0.0, 2.0)

## Multiplier applied to critical hit damage.
@export var crit_damage_scaling: Stat = Stat.new(1.0, true, 0.0, 2.0)


## Component references
var damage_component: DamageComponent = null
var targeting_area: TargetingArea = null
var local_targeting_area: TargetingArea = null

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
	
	# Try to find existing TargetingArea in children
	local_targeting_area = get_node_or_null("TargetingArea")
	
	if not local_targeting_area:
		# Create TargetingArea programmatically
		local_targeting_area = TargetingArea.new()
		local_targeting_area.name = "TargetingArea"
		local_targeting_area.collision_layer = target_collision_layer
		local_targeting_area.collision_mask = target_collision_mask
		add_child(local_targeting_area)
		
		# Create collision shape
		var targeting_shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = final_range.get_value()
		targeting_shape.shape = circle
		local_targeting_area.add_child(targeting_shape)
	
	# Configure targeting
	local_targeting_area.detection_range = final_range.get_value()

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
	if local_targeting_area:
		final_range.bind_to_property(local_targeting_area, "detection_range")
	
	# Bind continuous fire settings
	if weapon_component:
		weapon_component.fire_mode = fire_mode
		weapon_component.stop_condition = stop_condition
		weapon_component.fire_interval = fire_interval
		weapon_component.max_shots = max_shots
		weapon_component.max_duration = max_duration
		weapon_component.fire_on_start = fire_on_start
		weapon_component.cooldown_after_stop = cooldown_after_stop

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

func set_components(_damage: DamageComponent, _targeting: TargetingArea) -> void:
	damage_component = _damage
	targeting_area = _targeting

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if not enabled or not weapon_component:
		return
	
	# Update local targeting if we have it
	if local_targeting_area:
		local_targeting_area.update(delta)
	
	weapon_component.update(delta)

func fire() -> bool:
	if not enabled or not weapon_component:
		return false
	
	return weapon_component.fire()

func get_targeting() -> TargetingArea:
	return local_targeting_area if not use_global_targeting else targeting_area

func get_spawn_position() -> Vector2:
	if spawn_point and is_instance_valid(spawn_point):
		return spawn_point.global_position
	return global_position + spawn_offset.rotated(global_rotation)

func can_fire() -> bool:
	if not enabled or not weapon_component:
		return false
	
	# Allow firing if targeting not needed OR if we have valid targeting
	if not needs_targeting:
		return weapon_component.can_fire()
	
	var target_sys = get_targeting()
	if not target_sys:
		return false  # Needs targeting but doesn't have it
	
	return weapon_component.can_fire()

func get_cooldown_progress() -> float:
	return weapon_component.get_cooldown_progress() if weapon_component else 0.0

## Get stat by name (for buffs/upgrades)
func get_stat(stat_name: String) -> Stat:
	if stat_name.contains("."):
		var dot_index := stat_name.find(".")
		var stat_weapon_id = stat_name.substr(0, dot_index)
		if not stat_weapon_id.is_empty() and stat_weapon_id == weapon_id:
			return get_stat(stat_name.substr(dot_index + 1))
		return null

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

func stop_continuous_fire() -> void:
	if weapon_component:
		weapon_component.stop_continuous_fire()

func cancel_continuous_fire() -> void:
	if weapon_component:
		weapon_component.cancel_continuous_fire()

func is_continuous_firing() -> bool:
	return weapon_component.is_continuous_firing() if weapon_component else false

func get_continuous_fire_progress() -> float:
	return weapon_component.get_continuous_fire_progress() if weapon_component else 0.0
