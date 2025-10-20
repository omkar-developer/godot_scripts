class_name DeployableProjectile
extends BaseProjectile

## Static AOE damage zone (acid pool, fire, etc.).[br]
## Damages overlapping targets on tick intervals.[br]
## No movement, no velocity - pure stationary area damage.[br]
## Uses engine's built-in overlapping_areas for performance.

@export_group("Damage Tick Settings")
## Damage tick rate (seconds between damage applications)
@export var damage_tick_rate: float = 0.5

## Whether to apply damage immediately on spawn
@export var damage_on_spawn: bool = false

## Time since last damage tick (runtime)
var tick_timer: float = 0.0


func _on_spawned() -> void:
	super._on_spawned()
	
	# Apply damage immediately if configured
	if damage_on_spawn:
		_apply_tick_damage()


func _update_behavior(delta: float) -> void:
	# No movement for deployables
	
	# Update damage tick
	tick_timer += delta
	if tick_timer >= damage_tick_rate:
		tick_timer = 0.0
		_apply_tick_damage()


func _apply_tick_damage() -> void:
	if not damage_request:
		return
	
	# Get all overlapping areas (engine handles the array)
	var overlapping = get_overlapping_areas()
	
	for area in overlapping:
		if not is_instance_valid(area):
			continue
		
		# Try to get health component
		var health_comp: HealthComponent = area.get("health_component") as HealthComponent
		if health_comp:
			damage_request.process_damage(health_comp)
			hit_target.emit(area)


## Override on_hit to not destroy (deployables don't react to entry)
func on_hit(_target: Node) -> void:
	# Deployables don't destroy on hit, they tick damage
	# Damage is handled by _apply_tick_damage()
	pass


## Override terrain hit to not destroy (unless explicitly set)
func on_terrain_hit(body: Node) -> void:
	hit_terrain.emit(body)
	# Don't destroy on terrain for deployables by default
