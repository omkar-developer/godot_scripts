class_name BaseEnemy
extends BaseEntity

## High-performance base enemy class for kamikaze-style behavior.[br]
##[br]
## Optimized for thousands of instances. Chases target, deals collision damage,[br]
## and optionally destroys itself on hit. No unnecessary components or systems.

#region Exports - Enemy Settings

@export_group("Enemy Behavior")
@export var chase_enabled: bool = true
@export var update_direction_every_frame: bool = true
@export var update_interval: float = 0.1:  ## Only used if update_direction_every_frame is false
	set(value):
		update_interval = value
		if homing_component:
			homing_component.update_interval = value
	get:
		return homing_component.update_interval if homing_component else update_interval

@export_group("Collision Damage")
@export var collision_damage_enabled: bool = true
@export var destroy_on_collision: bool = true
@export var collision_cooldown: float = 0.0  ## Time between damage ticks (0 = instant death)

@export_group("Target")
@export var auto_find_player: bool = true
@export var player_group: String = "player"

#endregion

#region Component References

var homing_component: HomingComponent
var target: Node2D = null

#endregion

#region Internal State

var _collision_timer: float = 0.0
var _can_damage: bool = true

#endregion

#region Initialization

func _init() -> void:
	super._init()
	_create_enemy_components()


func _create_enemy_components() -> void:
	# Only create homing if chase is enabled
	if chase_enabled:
		# Use temp variable to avoid getter loopback
		var _homing_component = HomingComponent.new(movement_component, null)
		_homing_component.homing_enabled = true
		_homing_component.update_direction_every_frame = update_direction_every_frame
		_homing_component.update_interval = update_interval
		homing_component = _homing_component


func _ready() -> void:
	super._ready()
	
	# Auto-find player
	if auto_find_player:
		_find_player()
	
	# Connect collision signals only if needed
	if collision_damage_enabled:
		area_entered.connect(_on_area_collision)
		body_entered.connect(_on_body_collision)

#endregion

#region Update Loop

func _process(delta: float) -> void:	
	# Update homing
	if homing_component and chase_enabled and is_instance_valid(target):
		homing_component.update(delta)
	
	# Update collision cooldown
	if collision_cooldown > 0.0 and not _can_damage:
		_collision_timer -= delta
		if _collision_timer <= 0.0:
			_can_damage = true

	super._process(delta)

#endregion

#region Collision Handling

func _on_area_collision(area: Area2D) -> void:
	if not collision_damage_enabled or not _can_damage:
		return
	
	_try_damage_node(area)


func _on_body_collision(body: Node2D) -> void:
	if not collision_damage_enabled or not _can_damage:
		return
	
	_try_damage_node(body)


func _try_damage_node(node: Node) -> void:
	# Try to get health component
	var health_comp = node.get("health_component") as HealthComponent
	
	if health_comp and damage_component:
		damage_component.apply_to(health_comp)
		
		# Handle cooldown or instant death
		if collision_cooldown > 0.0:
			_can_damage = false
			_collision_timer = collision_cooldown
		elif destroy_on_collision:
			_on_collision_destroy()

#endregion

#region Virtual Methods

## Override for custom collision death behavior (particles, sound, etc.)
func _on_collision_destroy() -> void:
	queue_free()

#endregion

#region Public API

## Set the target to chase
func set_target(new_target: Node2D) -> void:
	if not is_instance_valid(new_target):
		return
	
	target = new_target
	
	if homing_component:
		homing_component.set_target(new_target)


## Find and set player as target
func _find_player() -> void:
	var players = get_tree().get_nodes_in_group(player_group)
	if not players.is_empty():
		set_target(players[0])


## Get current target
func get_target() -> Node2D:
	return target


## Check if has valid target
func has_target() -> bool:
	return is_instance_valid(target)


## Get distance to target
func get_distance_to_target() -> float:
	if not has_target():
		return INF
	return global_position.distance_to(target.global_position)


## Enable/disable chasing behavior
func set_chase_enabled(enabled: bool) -> void:
	chase_enabled = enabled
	if homing_component:
		homing_component.homing_enabled = enabled


## Enable/disable collision damage
func set_collision_damage_enabled(enabled: bool) -> void:
	collision_damage_enabled = enabled
	_can_damage = enabled

#endregion
