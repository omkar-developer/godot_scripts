class_name BaseProjectile
extends Area2D

## High-performance base projectile class.[br]
##[br]
## Lightweight projectile with optional homing, piercing, lifetime, and collision damage.[br>
## Optimized for spawning thousands of instances.

#region Exports - Projectile Settings

@export_group("Movement")
@export var projectile_speed: float = 200.0:
	set(value):
		projectile_speed = value
		if movement_component:
			movement_component.speed = value
	get:
		return movement_component.speed if movement_component else projectile_speed

@export var initial_direction: Vector2 = Vector2.RIGHT:
	set(value):
		initial_direction = value.normalized()
		if movement_component:
			movement_component.direction = initial_direction
	get:
		return movement_component.direction if movement_component else initial_direction

@export_group("Homing")
@export var homing_enabled: bool = false
@export var update_direction_every_frame: bool = true
@export var update_interval: float = 0.1:
	set(value):
		update_interval = value
		if homing_component:
			homing_component.update_interval = value
	get:
		return homing_component.update_interval if homing_component else update_interval

@export_group("Lifetime & Piercing")
@export var lifetime: float = 5.0:
	set(value):
		lifetime = value
		if lifetime_component:
			lifetime_component.lifetime = value
	get:
		return lifetime_component.lifetime if lifetime_component else lifetime

@export var pierce_count: int = 1:
	set(value):
		pierce_count = max(1, value)
	get:
		return pierce_count

@export_group("Damage")
@export var damage: float = 10.0:
	set(value):
		damage = value
		if damage_component:
			damage_component.damage = value
	get:
		return damage_component.damage if damage_component else damage

@export_group("Visual")
@export var look_at_direction: bool = true

#endregion

#region Component References

var movement_component: MovementComponent
var lifetime_component: LifetimeComponent
var homing_component: HomingComponent
var damage_component: DamageComponent
var look_component: LookComponent

#endregion

#region Internal State

var target: Node2D = null
var _hits_remaining: int = 1
var _hit_targets: Array = []  # Track what we've hit (for piercing)

#endregion

#region Initialization

func _init() -> void:
	_create_projectile_components()


func _create_projectile_components() -> void:
	# Movement component - use temp variable to avoid getter loopback
	var _movement_component = MovementComponent.new(self, projectile_speed)
	_movement_component.direction = initial_direction
	movement_component = _movement_component
	
	# Lifetime component - use temp variable to avoid getter loopback
	var _lifetime_component = LifetimeComponent.new(self, lifetime)
	lifetime_component = _lifetime_component
	
	# Damage component - use temp variable to avoid getter loopback
	var _damage_component = DamageComponent.new(self)
	_damage_component.damage = damage
	damage_component = _damage_component
	
	# Look component (rotate to face movement direction)
	if look_at_direction:
		var _look_component = LookComponent.new(movement_component)
		_look_component.look_mode = LookComponent.LookMode.VELOCITY
		look_component = _look_component
	
	# Homing component (optional) - use temp variable to avoid getter loopback
	if homing_enabled:
		var _homing_component = HomingComponent.new(movement_component, target)
		_homing_component.homing_enabled = true
		_homing_component.update_direction_every_frame = update_direction_every_frame
		_homing_component.update_interval = update_interval
		homing_component = _homing_component
	
	_hits_remaining = pierce_count


func _ready() -> void:
	# Connect collision
	area_entered.connect(_on_area_collision)
	body_entered.connect(_on_body_collision)

#endregion

#region Update Loop

func _process(delta: float) -> void:
	# Update homing first (sets direction)
	if homing_component and homing_enabled and is_instance_valid(target):
		homing_component.update(delta)
	
	# Update lifetime
	if lifetime_component:
		lifetime_component.update(delta)
	
	# Update look (rotation)
	if look_component and look_at_direction:
		look_component.update(delta)
	
	# Update movement last (applies movement in same frame)
	if movement_component:
		movement_component.update(delta)

#endregion

#region Collision Handling

func _on_area_collision(area: Area2D) -> void:
	_try_damage_and_pierce(area)


func _on_body_collision(body: Node2D) -> void:
	_try_damage_and_pierce(body)


func _try_damage_and_pierce(node: Node) -> void:
	# Skip if already hit this target (for piercing)
	if _hit_targets.has(node):
		return
	
	# Try to get health component
	var health_comp = node.get("health_component") as HealthComponent
	
	if health_comp and damage_component:
		damage_component.apply_to(health_comp)
		_hit_targets.append(node)
		
		# Reduce pierce count
		_hits_remaining -= 1
		
		# Call virtual method for custom behavior
		_on_hit(node, health_comp)
		
		# Destroy if no hits remaining
		if _hits_remaining <= 0:
			_on_pierce_exhausted()

#endregion

#region Virtual Methods

## Override for custom hit behavior (particles, sound, etc.)
func _on_hit(_target: Node, _health_comp: HealthComponent) -> void:
	pass

## Override for custom destruction behavior
func _on_pierce_exhausted() -> void:
	queue_free()

#endregion

#region Public API - Setup

## Set the projectile's target (for homing)
func set_target(new_target: Node2D) -> void:
	if not is_instance_valid(new_target):
		return
	
	target = new_target
	
	if homing_component:
		homing_component.set_target(new_target)


## Set the projectile's direction
func set_direction(direction: Vector2) -> void:
	initial_direction = direction  # Uses setter


## Set damage value
func set_damage(value: float) -> void:
	damage = value  # Uses setter


## Set pierce count
func set_pierce_count(count: int) -> void:
	pierce_count = count  # Uses setter
	_hits_remaining = count


## Set speed
func set_speed(speed: float) -> void:
	projectile_speed = speed  # Uses setter


## Set lifetime
func set_lifetime(time: float) -> void:
	lifetime = time  # Uses setter


## Enable/disable homing (must be called before _ready)
func set_homing_enabled(enabled: bool) -> void:
	homing_enabled = enabled
	if enabled and not homing_component:
		var _homing_component = HomingComponent.new(movement_component, target)
		_homing_component.homing_enabled = true
		homing_component = _homing_component

#endregion

#region Public API - Queries

## Get current direction
func get_direction() -> Vector2:
	return movement_component.direction if movement_component else Vector2.ZERO


## Get current velocity
func get_velocity() -> Vector2:
	return movement_component.velocity if movement_component else Vector2.ZERO


## Get remaining hits before destruction
func get_hits_remaining() -> int:
	return _hits_remaining


## Check if projectile has target
func has_target() -> bool:
	return is_instance_valid(target)

#endregion
