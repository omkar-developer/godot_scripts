class_name ProjectileWeapon
extends WeaponComponent

enum DirectionMode {
	TO_TARGET,
	OWNER_FORWARD,
	OWNER_ROTATION,
	MOUSE_POSITION,
	CUSTOM
}

var projectile_scene: PackedScene = null
var damage_component: DamageComponent = null
var targeting_component: TargetingComponent = null
var projectiles_per_shot: int = 1
var spread_angle: float = 0.0
var spawn_offset: Vector2 = Vector2.ZERO
var spawn_parent: Node = null
var projectile_speed: float = 300.0
var direction_mode: DirectionMode = DirectionMode.TO_TARGET
var custom_direction: Vector2 = Vector2.RIGHT
var inherit_owner_velocity: bool = false

signal projectile_spawned(projectile: Node, target: Node)
signal projectile_spawn_failed()

func _init(
	_owner: Object,
	_projectile_scene: PackedScene,
	_damage_component: DamageComponent,
	_targeting_component: TargetingComponent = null,
	_base_fire_rate: float = 1.0,
	_attack_speed: float = 0.0,
	_attack_speed_scaling: float = 1.0
) -> void:
	super._init(_owner, _base_fire_rate, _attack_speed, _attack_speed_scaling)
	
	projectile_scene = _projectile_scene
	damage_component = _damage_component
	targeting_component = _targeting_component

func _execute_fire() -> void:
	if not projectile_scene:
		push_warning("ProjectileWeapon: No projectile_scene set")
		projectile_spawn_failed.emit()
		return
	
	if not damage_component:
		push_warning("ProjectileWeapon: No damage_component set")
		projectile_spawn_failed.emit()
		return
	
	for i in range(projectiles_per_shot):
		_spawn_projectile(i)

func _spawn_projectile(index: int) -> void:
	var parent = _get_spawn_parent()
	if not parent:
		push_warning("ProjectileWeapon: No valid spawn parent found")
		projectile_spawn_failed.emit()
		return
	
	var projectile = projectile_scene.instantiate()
	if not projectile:
		push_warning("ProjectileWeapon: Failed to instantiate projectile")
		projectile_spawn_failed.emit()
		return
	
	var target = _get_projectile_target(index)
	var spawn_pos = _calculate_spawn_position()
	var direction = _calculate_projectile_direction(target, index)
	
	_setup_projectile(projectile, spawn_pos, direction, target)
	parent.add_child(projectile)
	projectile_spawned.emit(projectile, target)

func _get_spawn_parent() -> Node:
	if spawn_parent:
		return spawn_parent
	
	if owner is Node:
		var owner_node = owner as Node
		return owner_node.get_parent()
	
	return null

func _get_projectile_target(index: int) -> Node:
	if not targeting_component:
		return null
	
	if projectiles_per_shot == 1:
		return targeting_component.get_best_target()
	
	var targets = targeting_component.get_best_targets()
	return targets[index] if index < targets.size() else null

func _calculate_spawn_position() -> Vector2:
	if not owner is Node2D:
		return Vector2.ZERO
	
	var owner_node = owner as Node2D
	return owner_node.global_position + spawn_offset.rotated(owner_node.global_rotation)

func _calculate_projectile_direction(target: Node, index: int) -> Vector2:
	var base_direction: Vector2
	
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
	
	if projectiles_per_shot > 1 and spread_angle > 0.0:
		var spread = _calculate_spread_offset(index)
		base_direction = base_direction.rotated(deg_to_rad(spread))
	
	return base_direction

func _calculate_spread_offset(index: int) -> float:
	if projectiles_per_shot == 1:
		return 0.0
	
	var half_spread = spread_angle / 2.0
	var step = spread_angle / (projectiles_per_shot - 1) if projectiles_per_shot > 1 else 0.0
	return -half_spread + (step * index)

func _get_owner_forward() -> Vector2:
	if owner is Node2D:
		return Vector2.RIGHT.rotated((owner as Node2D).global_rotation)
	return Vector2.RIGHT

func _setup_projectile(projectile: Node, spawn_pos: Vector2, direction: Vector2, target: Node) -> void:
	if projectile is Node2D:
		projectile.global_position = spawn_pos
	
	if "damage_request" in projectile:
		projectile.damage_request = damage_component.create_request()
	
	if "target" in projectile:
		projectile.target = target
	
	if "velocity" in projectile:
		var velocity = direction * projectile_speed
		
		if inherit_owner_velocity and owner.get("velocity") != null:
			var owner_vel = owner.get("velocity")
			if owner_vel is Vector2:
				velocity += owner_vel
		
		projectile.velocity = velocity
	
	if "direction" in projectile:
		projectile.direction = direction
	
	if "speed" in projectile:
		projectile.speed = projectile_speed

func set_projectile_scene(scene: PackedScene) -> void:
	projectile_scene = scene

func set_spawn_offset(offset: Vector2) -> void:
	spawn_offset = offset

func set_projectiles_per_shot(count: int) -> void:
	projectiles_per_shot = maxi(1, count)

func set_spread_angle(angle: float) -> void:
	spread_angle = angle

func set_projectile_speed(speed: float) -> void:
	projectile_speed = speed

func set_direction_mode(mode: DirectionMode) -> void:
	direction_mode = mode

func set_custom_direction(direction: Vector2) -> void:
	custom_direction = direction.normalized()
