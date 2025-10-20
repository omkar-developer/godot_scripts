class_name LerpProjectile
extends Node2D

## Ultra-performance projectile for instant/fast attacks.[br]
## NO Area2D, NO physics - just lerps to target and applies damage.[br]
## Perfect for sniper bullets, lasers, instant hits.[br]
## Thousands of these have minimal overhead.

## Damage request to apply on hit (set by weapon at runtime)
var damage_request: DamageRequest = null

## Target node to lerp towards (set by weapon at runtime)
var target: Node = null

@export_group("Lerp Settings")
## Travel time to reach target (seconds)
@export var travel_time: float = 0.1

## Whether to rotate to face target
@export var rotate_to_target: bool = true

@export_group("Spawn Scenes")
## Scene to spawn on hit
@export var spawn_on_hit_scene: PackedScene = null

## Current lerp progress (runtime, 0.0 to 1.0)
var lerp_progress: float = 0.0

## Start position (runtime)
var start_position: Vector2 = Vector2.ZERO

## End position - target position (runtime)
var end_position: Vector2 = Vector2.ZERO

## Whether projectile is alive (runtime)
var is_alive: bool = true

signal hit_target(target: Node)
signal projectile_destroyed()


func _ready() -> void:
	start_position = global_position
	
	# Calculate end position from target
	if is_instance_valid(target) and target is Node2D:
		end_position = (target as Node2D).global_position
	else:
		# No valid target, destroy immediately
		_destroy()
		return
	
	# Set initial rotation
	if rotate_to_target:
		var direction = (end_position - start_position).normalized()
		if direction.length_squared() > 0:
			rotation = direction.angle()


func _process(delta: float) -> void:
	if not is_alive:
		return
	
	# Update lerp progress
	lerp_progress += delta / travel_time
	
	# Lerp position
	global_position = start_position.lerp(end_position, lerp_progress)
	
	# Check if reached target
	if lerp_progress >= 1.0:
		_on_reached_target()


func _on_reached_target() -> void:
	# Apply damage to target
	if is_instance_valid(target) and damage_request:
		var health_comp: HealthComponent = target.get("health_component") as HealthComponent
		if health_comp:
			damage_request.process_damage(health_comp)
	
	# Spawn hit effect
	if spawn_on_hit_scene:
		var instance = spawn_on_hit_scene.instantiate()
		if instance:
			if instance is Node2D:
				instance.global_position = global_position
			
			if "source" in instance:
				instance.source = self
			
			var parent = get_parent()
			if parent:
				parent.add_child(instance)
			else:
				get_tree().root.add_child(instance)
	
	hit_target.emit(target)
	_destroy()


func _destroy() -> void:
	if not is_alive:
		return
	
	is_alive = false
	projectile_destroyed.emit()
	queue_free()


## Set target and travel time
func setup(new_target: Node, new_travel_time: float = 0.1) -> void:
	target = new_target
	travel_time = new_travel_time
	
	# Recalculate end position if already in tree
	if is_inside_tree() and is_instance_valid(target) and target is Node2D:
		end_position = (target as Node2D).global_position


## Public destroy method
func destroy() -> void:
	_destroy()
