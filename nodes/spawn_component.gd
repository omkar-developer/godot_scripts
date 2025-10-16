class_name SpawnerComponent
extends Node2D

## Flexible spawner component for spawning entities with various patterns.[br]
##[br]
## Supports multiple spawn modes (interval, wave-based, list-based), spawn areas[br]
## (circle, rectangle, edges), and multiple spawn scenes. Can spawn continuously[br]
## or follow predefined spawn lists with delays.

## Spawn area shape types
enum AreaShape {
	CIRCLE,      ## Circular spawn area
	RECTANGLE,   ## Rectangular spawn area
	POINT        ## Single point (no randomization)
}

## Spawn location modes
enum SpawnLocation {
	VOLUME,      ## Spawn anywhere inside area
	EDGE,        ## Spawn on edge/perimeter only
	CORNERS      ## Spawn at corners only (rectangle only)
}

## Spawn modes
enum SpawnMode {
	INTERVAL,    ## Spawn at regular intervals
	WAVE,        ## Spawn in waves (burst of entities)
	LIST         ## Follow predefined spawn list with delays
}

## --- SPAWN SCENES ---

@export_group("Spawn Scenes")
## Single spawn scene (used when spawn_scenes array is empty)
@export var spawn_scene: PackedScene = null

## Multiple spawn scenes (takes priority over spawn_scene if not empty)
@export var spawn_scenes: Array[PackedScene] = []

## --- SPAWN AREA SETTINGS ---

@export_group("Spawn Area")
## Shape of spawn area
@export var area_shape: AreaShape = AreaShape.CIRCLE

## Where to spawn within area
@export var spawn_location: SpawnLocation = SpawnLocation.VOLUME

## Center position of spawn area (local to this node)
@export var spawn_center: Vector2 = Vector2.ZERO

## Circle: radius of spawn area
@export var spawn_radius: float = 100.0

## Rectangle: size of spawn area
@export var spawn_size: Vector2 = Vector2(200.0, 200.0)

## --- SPAWN MODE SETTINGS ---

@export_group("Spawn Mode")
## Current spawn mode
@export var spawn_mode: SpawnMode = SpawnMode.INTERVAL

@export_subgroup("Interval Mode")
## INTERVAL mode: time between spawns (seconds)
@export var spawn_interval: float = 2.0

## INTERVAL mode: number of entities per spawn
@export var entities_per_spawn: int = 1

@export_subgroup("Wave Mode")
## WAVE mode: time between waves (seconds)
@export var wave_interval: float = 5.0

## WAVE mode: entities per wave
@export var wave_size: int = 5

@export_subgroup("List Mode")
## LIST mode: spawn list format: { delay: [scene_indices], ... }
## Example: { 0.0: [0], 2.5: [1, 1], 5.0: [0, 1, 2] }
@export var spawn_list: Dictionary = {}

## --- SPAWN LIMITS ---

@export_group("Spawn Limits")
## Maximum entities alive at once (-1 = unlimited)
@export var max_alive: int = -1

## Maximum total spawns (-1 = unlimited)
@export var max_spawns: int = -1

## --- SPAWN PARENT ---

@export_group("Spawn Target")
## Where to add spawned entities (null = this node's parent)
@export var spawn_parent: Node = null

## --- AUTO START ---

@export_group("Auto Start")
## Whether to automatically start spawning on _ready()
@export var auto_start: bool = false

## Delay before auto-start (seconds)
@export var auto_start_delay: float = 0.0

## --- STATE ---

## Whether spawner is currently active
var is_spawning: bool = false

## Whether spawner is paused
var is_paused: bool = false

## Current spawn count
var spawn_count: int = 0

## Currently alive entities (weak references)
var alive_entities: Array = []

## Internal timer for interval/wave modes
var _spawn_timer: float = 0.0

## Internal index for list mode
var _list_index: int = 0

## Internal list of sorted delays for list mode
var _sorted_delays: Array = []

## Internal current delay target for list mode
var _current_delay: float = 0.0

## Internal auto-start timer
var _auto_start_timer: float = 0.0

## Internal flag for auto-start
var _waiting_for_auto_start: bool = false

## --- SIGNALS ---

## Emitted when an entity is spawned.[br]
## [param entity]: The spawned Node.[br]
## [param scene_index]: Index of spawn scene used (-1 if single scene).
signal entity_spawned(entity: Node, scene_index: int)

## Emitted when spawning starts.
signal spawning_started()

## Emitted when spawning stops.
signal spawning_stopped()

## Emitted when spawning is paused.
signal spawning_paused()

## Emitted when spawning is resumed.
signal spawning_resumed()

## Emitted when max_spawns limit is reached.
signal spawn_limit_reached()

## Emitted when a wave completes (WAVE mode only).[br]
## [param wave_number]: Wave number (0-indexed).
signal wave_completed(wave_number: int)

## Emitted when spawn list completes (LIST mode only).
signal list_completed()


func _ready() -> void:
	# Prepare spawn list if in LIST mode
	if spawn_mode == SpawnMode.LIST:
		_prepare_spawn_list()
	
	# Handle auto-start
	if auto_start:
		if auto_start_delay > 0.0:
			_waiting_for_auto_start = true
			_auto_start_timer = 0.0
		else:
			start_spawning()


func _process(delta: float) -> void:
	# Handle auto-start delay
	if _waiting_for_auto_start:
		_auto_start_timer += delta
		if _auto_start_timer >= auto_start_delay:
			_waiting_for_auto_start = false
			start_spawning()
		return
	
	if not is_spawning or is_paused:
		return
	
	# Clean up dead entities
	_cleanup_dead_entities()
	
	# Check spawn limits
	if _is_spawn_limit_reached():
		stop_spawning()
		return
	
	# Update spawn logic based on mode
	match spawn_mode:
		SpawnMode.INTERVAL:
			_update_interval_mode(delta)
		SpawnMode.WAVE:
			_update_wave_mode(delta)
		SpawnMode.LIST:
			_update_list_mode(delta)


## Start spawning entities.
func start_spawning() -> void:
	if is_spawning:
		return
	
	is_spawning = true
	is_paused = false
	_spawn_timer = 0.0
	_list_index = 0
	_current_delay = 0.0
	
	if spawn_mode == SpawnMode.LIST:
		_prepare_spawn_list()
	
	spawning_started.emit()


## Stop spawning entities.
func stop_spawning() -> void:
	if not is_spawning:
		return
	
	is_spawning = false
	is_paused = false
	spawning_stopped.emit()


## Pause spawning (can be resumed).
func pause_spawning() -> void:
	if not is_spawning or is_paused:
		return
	
	is_paused = true
	spawning_paused.emit()


## Resume spawning after pause.
func resume_spawning() -> void:
	if not is_spawning or not is_paused:
		return
	
	is_paused = false
	spawning_resumed.emit()


## Toggle pause state.
func toggle_pause() -> void:
	if is_paused:
		resume_spawning()
	else:
		pause_spawning()


## Manually spawn entity (bypasses timer/limits).[br]
## [param scene_index]: Index of scene to spawn (-1 = use spawn_scene or random).[br]
## [param position]: Optional position override (null = use spawn area).[br]
## [return]: Spawned entity Node, or null if failed.
func spawn_entity(scene_index: int = -1, spawn_position: Variant = null) -> Node:
	var scene := _get_spawn_scene(scene_index)
	if not scene:
		push_warning("SpawnerComponent: No spawn scene available")
		return null
	
	var entity = scene.instantiate()
	if not entity:
		push_warning("SpawnerComponent: Failed to instantiate scene")
		return null
	
	var parent := _get_spawn_parent()
	if not parent:
		push_warning("SpawnerComponent: No spawn parent available")
		entity.queue_free()
		return null
	
	# Set position
	if entity is Node2D:
		if spawn_position != null and spawn_position is Vector2:
			entity.global_position = spawn_position
		else:
			entity.global_position = _get_spawn_position()
	
	# Add to scene
	parent.add_child(entity)
	
	# Track entity
	alive_entities.append(entity)
	spawn_count += 1
	
	# Emit signal
	entity_spawned.emit(entity, scene_index)
	
	return entity


## Reset spawn counter and alive entities tracking.
func reset() -> void:
	spawn_count = 0
	alive_entities.clear()
	_spawn_timer = 0.0
	_list_index = 0
	_current_delay = 0.0


## Get number of currently alive entities.[br]
## [return]: Count of alive entities.
func get_alive_count() -> int:
	_cleanup_dead_entities()
	return alive_entities.size()


## Check if max alive limit is reached.[br]
## [return]: true if at or over limit.
func is_alive_limit_reached() -> bool:
	if max_alive < 0:
		return false
	return get_alive_count() >= max_alive


## Set spawn scene (single scene mode).[br]
## [param scene]: PackedScene to spawn.
func set_spawn_scene(scene: PackedScene) -> void:
	spawn_scene = scene


## Set multiple spawn scenes.[br]
## [param scenes]: Array of PackedScenes.
func set_spawn_scenes(scenes: Array[PackedScene]) -> void:
	spawn_scenes = scenes


## Add a spawn scene to the list.[br]
## [param scene]: PackedScene to add.[br]
## [return]: Index of added scene.
func add_spawn_scene(scene: PackedScene) -> int:
	spawn_scenes.append(scene)
	return spawn_scenes.size() - 1


## Set spawn area (circle).[br]
## [param center]: Center position (local).[br]
## [param radius]: Radius of circle.
func set_circle_area(center: Vector2, radius: float) -> void:
	area_shape = AreaShape.CIRCLE
	spawn_center = center
	spawn_radius = radius


## Set spawn area (rectangle).[br]
## [param center]: Center position (local).[br]
## [param size]: Size of rectangle.
func set_rectangle_area(center: Vector2, size: Vector2) -> void:
	area_shape = AreaShape.RECTANGLE
	spawn_center = center
	spawn_size = size


## Set spawn list for LIST mode.[br]
## [param list]: Dictionary { delay: [scene_indices], ... }
func set_spawn_list(list: Dictionary) -> void:
	spawn_list = list
	_prepare_spawn_list()


## --- INTERNAL METHODS ---

## Update INTERVAL spawn mode.
func _update_interval_mode(delta: float) -> void:
	_spawn_timer += delta
	
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		
		# Check alive limit
		if is_alive_limit_reached():
			return
		
		# Spawn entities
		for i in range(entities_per_spawn):
			if is_alive_limit_reached():
				break
			spawn_entity()


## Update WAVE spawn mode.
func _update_wave_mode(delta: float) -> void:
	_spawn_timer += delta
	
	if _spawn_timer >= wave_interval:
		_spawn_timer = 0.0
		
		# Check alive limit
		if is_alive_limit_reached():
			return
		
		# Spawn wave
		var spawned := 0
		for i in range(wave_size):
			if is_alive_limit_reached():
				break
			spawn_entity()
			spawned += 1
		
		if spawned > 0:
			var wave_num := floori(spawn_count / float(wave_size))
			wave_completed.emit(wave_num)


## Update LIST spawn mode.
func _update_list_mode(delta: float) -> void:
	if _list_index >= _sorted_delays.size():
		# List completed
		stop_spawning()
		list_completed.emit()
		return
	
	_current_delay += delta
	
	# Check if we should spawn next entry
	var target_delay: float = _sorted_delays[_list_index]
	
	if _current_delay >= target_delay:
		# Spawn entities for this delay
		var scene_indices: Array = spawn_list[target_delay]
		
		for scene_idx in scene_indices:
			if is_alive_limit_reached():
				break
			spawn_entity(scene_idx)
		
		# Move to next entry
		_list_index += 1


## Prepare spawn list (sort delays).
func _prepare_spawn_list() -> void:
	_sorted_delays.clear()
	
	for delay in spawn_list.keys():
		if delay is float or delay is int:
			_sorted_delays.append(float(delay))
	
	_sorted_delays.sort()
	_list_index = 0
	_current_delay = 0.0


## Get spawn scene based on index.[br]
## [param index]: Scene index (-1 = auto select).[br]
## [return]: PackedScene or null.
func _get_spawn_scene(index: int) -> PackedScene:
	# Multiple scenes mode
	if spawn_scenes.size() > 0:
		if index >= 0 and index < spawn_scenes.size():
			return spawn_scenes[index]
		# Random scene
		return spawn_scenes[randi() % spawn_scenes.size()]
	
	# Single scene mode
	return spawn_scene


## Get spawn parent node.
func _get_spawn_parent() -> Node:
	if spawn_parent:
		return spawn_parent
	
	return get_parent()


## Calculate spawn position based on area settings.[br]
## [return]: Global position Vector2.
func _get_spawn_position() -> Vector2:
	var local_pos: Vector2
	
	match area_shape:
		AreaShape.POINT:
			local_pos = spawn_center
		
		AreaShape.CIRCLE:
			local_pos = _get_circle_spawn_position()
		
		AreaShape.RECTANGLE:
			local_pos = _get_rectangle_spawn_position()
	
	return global_position + local_pos


## Get spawn position in circle.
func _get_circle_spawn_position() -> Vector2:
	match spawn_location:
		SpawnLocation.VOLUME:
			# Random point in circle
			var angle := randf() * TAU
			var radius := sqrt(randf()) * spawn_radius
			return spawn_center + Vector2(cos(angle), sin(angle)) * radius
		
		SpawnLocation.EDGE:
			# Random point on circle edge
			var angle := randf() * TAU
			return spawn_center + Vector2(cos(angle), sin(angle)) * spawn_radius
		
		_:
			return spawn_center


## Get spawn position in rectangle.
func _get_rectangle_spawn_position() -> Vector2:
	var half_size := spawn_size / 2.0
	
	match spawn_location:
		SpawnLocation.VOLUME:
			# Random point in rectangle
			var offset := Vector2(
				randf_range(-half_size.x, half_size.x),
				randf_range(-half_size.y, half_size.y)
			)
			return spawn_center + offset
		
		SpawnLocation.EDGE:
			# Random point on rectangle edge
			var side := randi() % 4
			match side:
				0:  # Top
					return spawn_center + Vector2(randf_range(-half_size.x, half_size.x), -half_size.y)
				1:  # Right
					return spawn_center + Vector2(half_size.x, randf_range(-half_size.y, half_size.y))
				2:  # Bottom
					return spawn_center + Vector2(randf_range(-half_size.x, half_size.x), half_size.y)
				3:  # Left
					return spawn_center + Vector2(-half_size.x, randf_range(-half_size.y, half_size.y))
		
		SpawnLocation.CORNERS:
			# Random corner
			var corner := randi() % 4
			var offset := half_size
			match corner:
				0:  # Top-left
					offset.x = -offset.x
					offset.y = -offset.y
				1:  # Top-right
					offset.y = -offset.y
				2:  # Bottom-right
					pass  # Already correct
				3:  # Bottom-left
					offset.x = -offset.x
			return spawn_center + offset
	return spawn_center


## Clean up dead entities from tracking array.
func _cleanup_dead_entities() -> void:
	alive_entities = alive_entities.filter(func(e): return is_instance_valid(e))


## Check if spawn limit reached.[br]
## [return]: true if any limit is reached.
func _is_spawn_limit_reached() -> bool:
	# Check max spawns
	if max_spawns >= 0 and spawn_count >= max_spawns:
		spawn_limit_reached.emit()
		return true
	
	# Check max alive
	if is_alive_limit_reached():
		return true
	
	return false


## Get spawner statistics.[br]
## [return]: Dictionary with stats.
func get_stats() -> Dictionary:
	return {
		"is_spawning": is_spawning,
		"is_paused": is_paused,
		"spawn_count": spawn_count,
		"alive_count": get_alive_count(),
		"spawn_mode": SpawnMode.keys()[spawn_mode],
		"area_shape": AreaShape.keys()[area_shape],
		"spawn_location": SpawnLocation.keys()[spawn_location]
	}
