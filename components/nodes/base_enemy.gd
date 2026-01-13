@icon("res://scripts/icons/enemy.svg")
class_name BaseEnemy
extends BaseEntity

## High-performance base enemy class for kamikaze-style behavior.
## Optimized for thousands of instances. Chases target, deals collision damage,
## and optionally destroys itself on hit.

#region ===========================
#region Exports - Enemy Settings
#region ===========================

@export_group("Enemy Behavior")
@export var chase_enabled: bool = true
@export var update_direction_every_frame: bool = true
@export var update_interval: float = 0.1:
	set(value):
		update_interval = value
		if homing_component:
			homing_component.update_interval = value
	get:
		return homing_component.update_interval if homing_component else update_interval


@export_group("Collision Damage")
@export var collision_damage_enabled: bool = true
@export var destroy_on_collision: bool = true
@export var collision_cooldown: float = 0.0
@export var damage: float = 10.0
@export var damage_type: int = 0


@export_group("On Destroy")

enum DestroySpawnMode {
	NONE,
	COLLISION_ONLY,
	ANY_DESTROY
}

enum SpawnQuantityMode {
	SPAWN_ALL,
	SPAWN_RANDOM_ONE
}

@export var spawn_mode: DestroySpawnMode = DestroySpawnMode.COLLISION_ONLY
@export var spawn_quantity_mode: SpawnQuantityMode = SpawnQuantityMode.SPAWN_ALL
@export var spawn_delay: float = 0.0
@export var scenes_to_spawn: Array[PackedScene] = []


@export_group("Target")
@export var auto_find_player: bool = true
@export var player_group: String = "player"

#endregion

#region ===========================
#region Component References
#region ===========================

var homing_component: HomingComponent
var target: Node2D = null

#endregion

#region ===========================
#region Internal State
#region ===========================

var _collision_timer: float = 0.0
var _can_damage: bool = true

var _destroyed_by_collision: bool = false
var _has_spawned: bool = false

#endregion

#region ===========================
#region Initialization
#region ===========================

func _init() -> void:
	super._init()
	_create_enemy_components()


func _create_enemy_components() -> void:
	if chase_enabled:
		var _homing_component = HomingComponent.new(movement_component, null)
		_homing_component.homing_enabled = true
		_homing_component.update_direction_every_frame = update_direction_every_frame
		_homing_component.update_interval = update_interval
		homing_component = _homing_component


func _ready() -> void:
	super._ready()
	
	if auto_find_player:
		_find_player()
	
	if collision_damage_enabled:
		area_entered.connect(_on_area_collision)
		body_entered.connect(_on_body_collision)

#endregion

#region ===========================
#region Update Loop
#region ===========================

func _process(delta: float) -> void:	
	if homing_component and chase_enabled and is_instance_valid(target):
		homing_component.update(delta)
	
	if collision_cooldown > 0.0 and not _can_damage:
		_collision_timer -= delta
		if _collision_timer <= 0.0:
			_can_damage = true

	super._process(delta)

#endregion

#region ===========================
#region Collision Handling
#region ===========================

func _on_area_collision(area: Area2D) -> void:
	if not collision_damage_enabled or not _can_damage:
		return
	_try_damage_node(area)


func _on_body_collision(body: Node2D) -> void:
	if not collision_damage_enabled or not _can_damage:
		return
	_try_damage_node(body)


func _try_damage_node(node: Node) -> void:
	if not damage_component:
		return

	var request: DamageRequest = damage_component.create_request(
		damage,
		damage_type,
		0,
		0,
		Vector2.ZERO
	)

	var result: DamageResult = request.apply_to_target(node)

	if result:
		if collision_cooldown > 0.0:
			_can_damage = false
			_collision_timer = collision_cooldown
		elif destroy_on_collision:
			_on_collision_destroy()

#endregion

#region ===========================
#region Destroy / Spawn Logic
#region ===========================

func _on_collision_destroy() -> void:
	_destroyed_by_collision = true
	_try_spawn_on_destroy()
	queue_free()


func _exit_tree() -> void:
	if spawn_mode == DestroySpawnMode.ANY_DESTROY:
		_try_spawn_on_destroy()


func _try_spawn_on_destroy() -> void:
	if _has_spawned:
		return
	
	if scenes_to_spawn.is_empty():
		return
	
	if spawn_mode == DestroySpawnMode.NONE:
		return
	
	if spawn_mode == DestroySpawnMode.COLLISION_ONLY and not _destroyed_by_collision:
		return
	
	_has_spawned = true
	
	if spawn_delay > 0.0:
		await get_tree().create_timer(spawn_delay).timeout
	
	var parent := get_parent()
	if not parent:
		return
	
	match spawn_quantity_mode:
		SpawnQuantityMode.SPAWN_ALL:
			for scene in scenes_to_spawn:
				_spawn_scene(scene, parent)
		
		SpawnQuantityMode.SPAWN_RANDOM_ONE:
			var scene = scenes_to_spawn.pick_random()
			_spawn_scene(scene, parent)


func _spawn_scene(scene: PackedScene, parent: Node) -> void:
	if not scene:
		return
	
	var instance = scene.instantiate()
	instance.global_position = global_position
	parent.call_deferred("add_child", instance)

#endregion

#region ===========================
#region Public API
#region ===========================

func set_target(new_target: Node2D) -> void:
	if not is_instance_valid(new_target):
		return
	
	target = new_target
	
	if homing_component:
		homing_component.set_target(new_target)


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group(player_group)
	if not players.is_empty():
		set_target(players[0])


func get_target() -> Node2D:
	return target


func has_target() -> bool:
	return is_instance_valid(target)


func get_distance_to_target() -> float:
	if not has_target():
		return INF
	return global_position.distance_to(target.global_position)


func set_chase_enabled(enabled: bool) -> void:
	chase_enabled = enabled
	if homing_component:
		homing_component.homing_enabled = enabled


func set_collision_damage_enabled(enabled: bool) -> void:
	collision_damage_enabled = enabled
	_can_damage = enabled

#endregion
