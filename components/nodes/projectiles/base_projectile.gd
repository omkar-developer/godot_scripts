@icon("res://scripts/icons/projectile.svg")
class_name BaseProjectile
extends Area2D

## Base class for all projectile types.[br]
## Handles damage application, lifetime, collision setup, and scene spawning.[br]
## Optimized for high-performance bullet-hell games.

## Damage request to apply on hit (set by weapon at runtime)
var damage_request: DamageRequest = null

@export_group("Lifetime")
## Lifetime before auto-destruction (seconds)
@export var lifetime: float = 5.0

## Current age of projectile (runtime, don't set)
var age: float = 0.0

@export_group("Spawn Scenes")
## Scene to spawn when projectile is destroyed
@export var spawn_on_death_scene: PackedScene = null

## Scene to spawn on each hit
@export var spawn_on_hit_scene: PackedScene = null

@export_group("Behavior")
## Whether to rotate sprite to face movement direction
@export var rotate_to_direction: bool = true

## Whether to destroy on terrain hit
@export var destroy_on_terrain: bool = true

## Whether projectile is alive (runtime)
var is_alive: bool = true

signal hit_target(target: Node)
signal hit_terrain(body: Node)
signal projectile_destroyed()


func _ready() -> void:
	# Connect collision signals
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# Setup initial state
	_on_spawned()


func _process(delta: float) -> void:
	if not is_alive:
		return
	
	# Update lifetime
	age += delta
	if age >= lifetime:
		_destroy()
		return
	
	# Update behavior (override in derived classes)
	_update_behavior(delta)
	
	# Update rotation (override in derived classes if needed)
	if rotate_to_direction:
		_update_rotation()


## Virtual method for derived classes to implement behavior
func _update_behavior(_delta: float) -> void:
	pass


## Virtual method for rotation logic (override for velocity-based, etc.)
func _update_rotation() -> void:
	pass


## Virtual method called when projectile spawns
func _on_spawned() -> void:
	pass


## Virtual method called when projectile hits a target
func on_hit(target: Node) -> void:
	# Try to apply damage
	if damage_request:
		var health_comp: HealthComponent = target.get("health_component") as HealthComponent
		
		if health_comp:
			health_comp.process_damage(damage_request)
		elif target.has_method("process_damage"):
			# Fallback for lightweight targets without health component
			target.process_damage(damage_request)
	
	# Spawn hit effect
	if spawn_on_hit_scene:
		_spawn_scene(spawn_on_hit_scene, global_position)
	
	hit_target.emit(target)


## Virtual method called when projectile hits terrain
func on_terrain_hit(body: Node) -> void:
	hit_terrain.emit(body)
	
	if destroy_on_terrain:
		_destroy()


func _on_area_entered(area: Area2D) -> void:
	if not is_alive:
		return
	
	on_hit(area)


func _on_body_entered(body: Node2D) -> void:
	if not is_alive:
		return
	
	on_terrain_hit(body)


## Destroy the projectile
func _destroy() -> void:
	if not is_alive:
		return
	
	is_alive = false
	
	# Spawn death effect
	if spawn_on_death_scene:
		_spawn_scene(spawn_on_death_scene, global_position)
	
	projectile_destroyed.emit()
	queue_free()


## Spawn a scene at position
func _spawn_scene(scene: PackedScene, pos: Vector2) -> Node:
	var instance = scene.instantiate()
	if not instance:
		return null
	
	# Set position if Node2D
	if instance is Node2D:
		instance.global_position = pos
	
	# Setup common properties
	if "source" in instance:
		instance.source = self
	
	if "damage_request" in instance and damage_request:
		instance.damage_request = damage_request
	
	# Add to scene
	var parent = get_parent()
	if parent:
		parent.add_child(instance)
	else:
		get_tree().root.add_child(instance)
	
	return instance


## Setup collision layers/mask (called by weapon at runtime)
func setup_collision(layer: int, mask: int) -> void:
	collision_layer = layer
	collision_mask = mask

## Public destroy method
func destroy() -> void:
	_destroy()
