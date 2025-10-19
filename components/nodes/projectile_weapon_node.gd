@tool
class_name ProjectileWeaponNode
extends WeaponNode

## Projectile-specific settings
@export var projectile_scene: PackedScene = null:
	set(value):
		projectile_scene = value
		if projectile_weapon:
			projectile_weapon.projectile_scene = value
	get:
		return projectile_weapon.projectile_scene if projectile_weapon else projectile_scene

@export var projectiles_per_shot: int = 1:
	set(value):
		projectiles_per_shot = value
		if projectile_weapon:
			projectile_weapon.projectiles_per_shot = value
	get:
		return projectile_weapon.projectiles_per_shot if projectile_weapon else projectiles_per_shot

@export var spread_angle: float = 0.0:
	set(value):
		spread_angle = value
		if projectile_weapon:
			projectile_weapon.spread_angle = value
	get:
		return projectile_weapon.spread_angle if projectile_weapon else spread_angle

@export var direction_mode: ProjectileWeapon.DirectionMode = ProjectileWeapon.DirectionMode.TO_TARGET:
	set(value):
		direction_mode = value
		if projectile_weapon:
			projectile_weapon.direction_mode = value
	get:
		return projectile_weapon.direction_mode if projectile_weapon else direction_mode

@export var custom_direction: Vector2 = Vector2.RIGHT:
	set(value):
		custom_direction = value
		if projectile_weapon:
			projectile_weapon.custom_direction = value
	get:
		return projectile_weapon.custom_direction if projectile_weapon else custom_direction

@export var inherit_owner_velocity: bool = false:
	set(value):
		inherit_owner_velocity = value
		if projectile_weapon:
			projectile_weapon.inherit_owner_velocity = value
	get:
		return projectile_weapon.inherit_owner_velocity if projectile_weapon else inherit_owner_velocity

@export var spawn_parent: Node = null:
	set(value):
		spawn_parent = value
		if projectile_weapon:
			projectile_weapon.spawn_parent = value
	get:
		return projectile_weapon.spawn_parent if projectile_weapon else spawn_parent

## Reference to the ProjectileWeapon component
var projectile_weapon: ProjectileWeapon = null

signal projectile_spawned(projectile: Node, target: Node)
signal projectile_spawn_failed

func _setup_weapon_component() -> void:
	# Create ProjectileWeapon component
	var _projectile_weapon = ProjectileWeapon.new(
		self,
		projectile_scene,
		damage_component,
		get_targeting(),
		final_fire_rate.get_value()
	)
	
	# Set initial properties
	_projectile_weapon.auto_fire = auto_fire
	_projectile_weapon.projectiles_per_shot = projectiles_per_shot
	_projectile_weapon.spread_angle = spread_angle
	_projectile_weapon.spawn_offset = spawn_offset
	_projectile_weapon.direction_mode = direction_mode
	_projectile_weapon.custom_direction = custom_direction
	_projectile_weapon.inherit_owner_velocity = inherit_owner_velocity
	_projectile_weapon.spawn_parent = spawn_parent
	
	projectile_weapon = _projectile_weapon
	# Set as weapon_component for base class
	weapon_component = projectile_weapon

func _bind_stats_to_components() -> void:
	super._bind_stats_to_components()
	
	# Bind projectile speed to component
	if projectile_weapon:
		final_projectile_speed.bind_to_property(projectile_weapon, "projectile_speed")

func _connect_signals() -> void:
	super._connect_signals()
	
	# Connect projectile-specific signals
	if projectile_weapon:
		projectile_weapon.projectile_spawned.connect(_on_projectile_spawned)
		projectile_weapon.projectile_spawn_failed.connect(_on_projectile_spawn_failed)

func _on_projectile_spawned(_projectile: Node, _target: Node) -> void:
	projectile_spawned.emit(_projectile, _target)
	# Override in subclasses for custom behavior
	pass

func _on_projectile_spawn_failed() -> void:
	projectile_spawn_failed.emit()
	# Override in subclasses for custom behavior
	pass
