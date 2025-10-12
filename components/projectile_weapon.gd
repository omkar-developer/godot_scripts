class_name ProjectileWeapon
extends WeaponComponent

## Projectile-spawning weapon that instantiates projectiles with damage and targeting.[br]
##[br]
## This weapon type spawns projectile scenes and passes them a DamageRequest and[br]
## optional target. The projectile is responsible for movement and collision.[br]
## Supports single/multi-shot, spread patterns, and custom spawn positions.

## Projectile scene to instantiate
var projectile_scene: PackedScene = null

## Damage component for creating damage requests
var damage_component: DamageComponent = null

## Optional targeting component for auto-targeting projectiles
var targeting_component: TargetingComponent = null

## Number of projectiles to spawn per shot (for multi-shot/shotgun patterns)
var projectiles_per_shot: int = 1

## Spread angle in degrees (0 = no spread, 45 = ±22.5° cone)
var spread_angle: float = 0.0

## Spawn position offset from owner (in owner's local space)
var spawn_offset: Vector2 = Vector2.ZERO

## Projectile spawn parent (where to add_child). If null, uses owner's parent
var spawn_parent: Node = null

## Initial velocity for projectiles (magnitude). Projectile must have velocity property
var projectile_speed: float = 300.0

## Direction mode for projectiles
enum DirectionMode {
	TO_TARGET,      ## Aim at targeted enemy (requires targeting_component)
	OWNER_FORWARD,  ## Use owner's forward direction (global_transform.x)
	OWNER_ROTATION, ## Use owner's rotation
	MOUSE_POSITION, ## Aim towards mouse position (2D only)
	CUSTOM          ## Use custom_direction vector
}

## How projectiles determine their direction
var direction_mode: DirectionMode = DirectionMode.TO_TARGET

## Custom direction vector (used when direction_mode = CUSTOM)
var custom_direction: Vector2 = Vector2.RIGHT

## Whether to inherit owner's velocity (for moving shooters)
var inherit_owner_velocity: bool = false

## Emitted when a projectile is spawned.[br]
## [param projectile]: The instantiated projectile Node.[br]
## [param target]: The target Node (null if no targeting).
signal projectile_spawned(projectile: Node, target: Node)

## Emitted when projectile spawning fails (no scene or parent).
signal projectile_spawn_failed()


## Constructor.[br]
## [param _owner]: The Object that owns this weapon.[br]
## [param _projectile_scene]: PackedScene to instantiate for projectiles.[br]
## [param _damage_component]: DamageComponent for creating damage requests.[br]
## [param _targeting_component]: Optional TargetingComponent for auto-aim.[br]
## [param _base_fire_rate]: Fire rate (shots/sec) - can be float, Stat, or stat name.[br]
## [param _attack_speed]: Attack speed - can be float, Stat, or stat name.[br]
## [param _attack_speed_scaling]: How much attack speed affects weapon (0.0-1.0).
func _init(
	_owner: Object,
	_projectile_scene: PackedScene,
	_damage_component: DamageComponent,
	_targeting_component: TargetingComponent = null,
	_base_fire_rate = 1.0,
	_attack_speed = "attack_speed",
	_attack_speed_scaling: float = 1.0
) -> void:
	super._init(_owner, _base_fire_rate, _attack_speed, _attack_speed_scaling)
	
	projectile_scene = _projectile_scene
	damage_component = _damage_component
	targeting_component = _targeting_component


## Override: Execute weapon fire - spawns projectile(s).
func _execute_fire() -> void:
	if not projectile_scene:
		push_warning("ProjectileWeapon: No projectile_scene set")
		projectile_spawn_failed.emit()
		return
	
	if not damage_component:
		push_warning("ProjectileWeapon: No damage_component set")
		projectile_spawn_failed.emit()
		return
	
	# Spawn multiple projectiles if configured
	for i in range(projectiles_per_shot):
		_spawn_projectile(i)


## Internal: Spawn a single projectile.[br]
## [param index]: Projectile index (for spread calculations).
func _spawn_projectile(index: int) -> void:
	# Get spawn parent
	var parent = _get_spawn_parent()
	if not parent:
		push_warning("ProjectileWeapon: No valid spawn parent found")
		projectile_spawn_failed.emit()
		return
	
	# Instantiate projectile
	var projectile = projectile_scene.instantiate()
	if not projectile:
		push_warning("ProjectileWeapon: Failed to instantiate projectile")
		projectile_spawn_failed.emit()
		return
	
	# Get target (if targeting enabled)
	var target = _get_projectile_target(index)
	
	# Calculate spawn position
	var spawn_pos = _calculate_spawn_position()
	
	# Calculate direction
	var direction = _calculate_projectile_direction(target, index)
	
	# Setup projectile
	_setup_projectile(projectile, spawn_pos, direction, target)
	
	# Add to scene
	parent.add_child(projectile)
	
	# Emit signal
	projectile_spawned.emit(projectile, target)


## Internal: Get the parent node for spawning projectiles.
func _get_spawn_parent() -> Node:
	if spawn_parent:
		return spawn_parent
	
	if owner is Node:
		var owner_node = owner as Node
		return owner_node.get_parent()
	
	return null


## Internal: Get target for projectile.[br]
## [param index]: Projectile index (for multi-target support).
func _get_projectile_target(index: int) -> Node:
	if not targeting_component:
		return null
	
	if projectiles_per_shot == 1:
		return targeting_component.get_best_target()
	
	# Multi-shot: get multiple targets if available
	var targets = targeting_component.get_best_targets()
	return targets[index] if index < targets.size() else null


## Internal: Calculate spawn position in global space.
func _calculate_spawn_position() -> Vector2:
	if not owner is Node2D:
		return Vector2.ZERO
	
	var owner_node = owner as Node2D
	return owner_node.global_position + spawn_offset.rotated(owner_node.global_rotation)


## Internal: Calculate projectile direction.[br]
## [param target]: Target node (can be null).[br]
## [param index]: Projectile index for spread calculation.
func _calculate_projectile_direction(target: Node, index: int) -> Vector2:
	var base_direction: Vector2
	
	# Get base direction based on mode
	match direction_mode:
		DirectionMode.TO_TARGET:
			if target and target is Node2D:
				if owner is Node2D:
					base_direction = (target.global_position - (owner as Node2D).global_position).normalized()
				else:
					base_direction = Vector2.RIGHT
			else:
				base_direction = _get_owner_forward()
		
		DirectionMode.OWNER_FORWARD:
			base_direction = _get_owner_forward()
		
		DirectionMode.OWNER_ROTATION:
			if owner is Node2D:
				base_direction = Vector2.RIGHT.rotated((owner as Node2D).global_rotation)
			else:
				base_direction = Vector2.RIGHT
		
		DirectionMode.MOUSE_POSITION:
			if owner is Node2D:
				var mouse_pos = (owner as Node2D).get_global_mouse_position()
				base_direction = (mouse_pos - (owner as Node2D).global_position).normalized()
			else:
				base_direction = Vector2.RIGHT
		
		DirectionMode.CUSTOM:
			base_direction = custom_direction.normalized()
	
	# Apply spread if multiple projectiles
	if projectiles_per_shot > 1 and spread_angle > 0.0:
		var spread = _calculate_spread_offset(index)
		base_direction = base_direction.rotated(deg_to_rad(spread))
	
	return base_direction


## Internal: Calculate spread offset for projectile.[br]
## [param index]: Projectile index.[br]
## [return]: Angle offset in degrees.
func _calculate_spread_offset(index: int) -> float:
	if projectiles_per_shot == 1:
		return 0.0
	
	# Distribute projectiles evenly across spread angle
	var half_spread = spread_angle / 2.0
	var step = spread_angle / (projectiles_per_shot - 1) if projectiles_per_shot > 1 else 0.0
	return -half_spread + (step * index)


## Internal: Get owner's forward direction.
func _get_owner_forward() -> Vector2:
	if owner is Node2D:
		return Vector2.RIGHT.rotated((owner as Node2D).global_rotation)
	return Vector2.RIGHT


## Internal: Setup projectile properties.[br]
## [param projectile]: The instantiated projectile Node.[br]
## [param spawn_pos]: Global spawn position.[br]
## [param direction]: Movement direction (normalized).[br]
## [param target]: Target node (can be null).
func _setup_projectile(projectile: Node, spawn_pos: Vector2, direction: Vector2, target: Node) -> void:
	# Set position
	if projectile is Node2D:
		projectile.global_position = spawn_pos
	
	# Set damage request (duck typing - projectile should have damage_request property)
	if "damage_request" in projectile:
		projectile.damage_request = damage_component.create_request()
	
	# Set target (duck typing)
	if "target" in projectile:
		projectile.target = target
	
	# Set velocity (duck typing)
	if "velocity" in projectile:
		var velocity = direction * projectile_speed
		
		# Inherit owner velocity if enabled
		if inherit_owner_velocity and owner.get("velocity") != null:
			var owner_vel = owner.get("velocity")
			if owner_vel is Vector2:
				velocity += owner_vel
		
		projectile.velocity = velocity
	
	# Set direction (duck typing - some projectiles might use this instead)
	if "direction" in projectile:
		projectile.direction = direction
	
	# Set speed (duck typing)
	if "speed" in projectile:
		projectile.speed = projectile_speed


## Set the projectile scene to spawn.[br]
## [param scene]: PackedScene for projectiles.
func set_projectile_scene(scene: PackedScene) -> void:
	projectile_scene = scene


## Set spawn position offset.[br]
## [param offset]: Offset in owner's local space.
func set_spawn_offset(offset: Vector2) -> void:
	spawn_offset = offset


## Set projectile count per shot.[br]
## [param count]: Number of projectiles to spawn (1+ for shotgun patterns).
func set_projectiles_per_shot(count: int) -> void:
	projectiles_per_shot = maxi(1, count)


## Set spread angle for multi-shot.[br]
## [param angle]: Spread angle in degrees (0 = no spread).
func set_spread_angle(angle: float) -> void:
	spread_angle = angle


## Set projectile speed.[br]
## [param speed]: Initial velocity magnitude.
func set_projectile_speed(speed: float) -> void:
	projectile_speed = speed


## Set direction mode.[br]
## [param mode]: DirectionMode enum value.
func set_direction_mode(mode: DirectionMode) -> void:
	direction_mode = mode


## Set custom direction (used when mode = CUSTOM).[br]
## [param direction]: Direction vector (will be normalized).
func set_custom_direction(direction: Vector2) -> void:
	custom_direction = direction.normalized()
