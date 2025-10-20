class_name ProjectileNode
extends Area2D

## Optimized projectile for high-performance bullet-hell games.[br]
## Handles movement, collision, damage application, and pierce mechanics.[br]
## Designed to handle thousands of instances efficiently.

## Damage request to apply on hit (set by weapon)
var damage_request: DamageRequest = null

## Velocity vector for movement
var velocity: Vector2 = Vector2.ZERO

## Direction vector (normalized, for reference)
var direction: Vector2 = Vector2.RIGHT

## Speed value (for reference, actual movement uses velocity)
var speed: float = 300.0

## Target node (optional, for homing or tracking)
var target: Node = null

## Projectile behavior component
var projectile_component: ProjectileComponent = null

## Lifetime component for auto-destruction
var lifetime_component: LifetimeComponent = null

## Whether to rotate sprite to face movement direction
var rotate_to_direction: bool = true


func _init() -> void:
	# Setup collision
	# collision_layer = 0
	# collision_mask = 0
	monitoring = true
	monitorable = false
	
	# Create components with temp pattern
	var temp_projectile = ProjectileComponent.new(self, 0)
	temp_projectile.destroy_on_terrain = true
	temp_projectile.auto_destroy = true
	temp_projectile.track_hit_targets = true
	projectile_component = temp_projectile
	
	var temp_lifetime = LifetimeComponent.new(self, 5.0)
	lifetime_component = temp_lifetime
	
	# Connect signals
	projectile_component.should_destroy.connect(_on_should_destroy)


func _ready() -> void:
	# Connect area entered signal
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# Set initial rotation if needed
	if rotate_to_direction and velocity.length_squared() > 0:
		rotation = velocity.angle()


func _process(delta: float) -> void:
	# Update position
	global_position += velocity * delta
	
	# Update rotation to face movement direction
	if rotate_to_direction and velocity.length_squared() > 0:
		rotation = velocity.angle()
	
	# Update lifetime
	if lifetime_component:
		lifetime_component.update(delta)


func _on_area_entered(area: Area2D) -> void:
	# Try to get health component
	var health_comp: HealthComponent = area.get("health_component") as HealthComponent
	
	if health_comp and damage_request:
		# Register hit with projectile component
		if projectile_component and projectile_component.register_hit(area):
			# Apply damage
			health_comp.process_damage(damage_request)
	else:
		# Hit something without health (terrain/obstacle)
		if projectile_component:
			projectile_component.register_terrain_hit()


func _on_body_entered(_body: Node2D) -> void:
	# Hit terrain/wall
	if projectile_component:
		projectile_component.register_terrain_hit()


func _on_should_destroy() -> void:
	queue_free()


## Set the damage request for this projectile.[br]
## [param request]: The DamageRequest to apply on hit.
func set_damage_request(request: DamageRequest) -> void:
	damage_request = request


## Set pierce count for this projectile.[br]
## [param pierce_count]: Number of targets to pierce (-1 for infinite).
func set_pierce_count(pierce_count: int) -> void:
	if projectile_component:
		projectile_component.set_pierce_count(pierce_count)


## Set lifetime duration.[br]
## [param duration]: How long projectile lives in seconds.
func set_lifetime(duration: float) -> void:
	if lifetime_component:
		lifetime_component.max_lifetime = duration


## Set whether to destroy on terrain hit.[br]
## [param destroy]: Whether to destroy on terrain collision.
func set_destroy_on_terrain(destroy: bool) -> void:
	if projectile_component:
		projectile_component.set_destroy_on_terrain(destroy)


## Configure collision layers.[br]
## [param layer]: Collision layer bits.[br]
## [param mask]: Collision mask bits.
func set_collision(layer: int, mask: int) -> void:
	collision_layer = layer
	collision_mask = mask
