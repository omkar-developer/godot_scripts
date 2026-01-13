@tool
class_name Spawner2D
extends Node2D

## Spatial spawner component with patterns, timers, and visual helpers for 2D.[br]
##[br]
## Uses SpawnerCore (RefCounted) for spawning logic and SpawnGeometry2D child for area geometry.

## Spawn timing modes
enum TimingMode {
	INTERVAL,    ## Spawn at regular intervals
	WAVE,        ## Spawn in waves (burst of entities)
	LIST         ## Follow predefined spawn list with delays
}

## --- SPAWN SCENES (delegated to core) ---

@export_group("Spawn Scenes")
## Single spawn scene (used when spawn_scenes array is empty)
@export var spawn_scene: PackedScene = null:
	set(value):
		spawn_scene = value
		if spawner_core:
			spawner_core.spawn_scene = value
	get:
		return spawner_core.spawn_scene if spawner_core else spawn_scene

## Multiple spawn scenes (takes priority over spawn_scene if not empty)
@export var spawn_scenes: Array[PackedScene] = []:
	set(value):
		spawn_scenes = value
		if spawner_core:
			spawner_core.spawn_scenes = value
	get:
		return spawner_core.spawn_scenes if spawner_core else spawn_scenes

## --- SPAWN MODE (delegated to core) ---

@export_group("Spawn Configuration")
## Spawn mode affects what features are enabled
@export var spawn_mode: SpawnerCore.SpawnMode = SpawnerCore.SpawnMode.FULL:
	set(value):
		spawn_mode = value
		if spawner_core:
			spawner_core.spawn_mode = value
	get:
		return spawner_core.spawn_mode if spawner_core else spawn_mode

@export var manual_mode: bool = false

## --- SPAWN LIMITS (delegated to core) ---

@export_group("Spawn Limits")
## Maximum entities alive at once (-1 = unlimited)
@export var max_alive: int = -1:
	set(value):
		max_alive = value
		if spawner_core:
			spawner_core.max_alive = value
	get:
		return spawner_core.max_alive if spawner_core else max_alive

## Maximum total spawns (-1 = unlimited)
@export var max_spawns: int = -1:
	set(value):
		max_spawns = value
		if spawner_core:
			spawner_core.max_spawns = value
	get:
		return spawner_core.max_spawns if spawner_core else max_spawns

## --- SPAWN PARENT (delegated to core) ---

@export_group("Spawn Target")
## Where to add spawned entities (null = this node)
@export var spawn_parent: Node = null:
	set(value):
		spawn_parent = value
		if spawner_core:
			spawner_core.spawn_parent = value if value else self
	get:
		return spawn_parent

## --- CUSTOM PROPERTIES (delegated to core) ---

@export_group("Custom Properties")
## Properties to set on spawned entities { "property_name": value }
## Supports nested properties using dot notation: "health_component.max_health"
## Only used in FULL mode
@export var spawn_properties: Dictionary[String, Variant] = {}:
	set(value):
		spawn_properties = value
		if spawner_core:
			spawner_core.spawn_properties = value
	get:
		return spawner_core.spawn_properties if spawner_core else spawn_properties

## Per-scene properties (indexed by spawn_scenes array index)
## These override spawn_properties for specific scenes
## Only used in FULL mode
@export var spawn_scene_properties: Array[Dictionary] = []:
	set(value):
		spawn_scene_properties = value
		if spawner_core:
			spawner_core.spawn_scene_properties = value
	get:
		return spawner_core.spawn_scene_properties if spawner_core else spawn_scene_properties

@export_group("Advanced Properties")
## Advanced property value declarations: { "property_path": SpawnPropertyValue }
## Property path supports dot notation (e.g., "health_component.max_health")
## Only used in FULL mode
@export var advanced_properties: Dictionary[String, SpawnPropertyValue] = {}:
	set(value):
		advanced_properties = value
		if spawner_core:
			spawner_core.advanced_properties = value
	get:
		return spawner_core.advanced_properties if spawner_core else advanced_properties

## Per-scene advanced property assignments (JSON format for easier editing)
## Format: [["prop1", "prop2"], ["prop3"], ["prop1", "prop3"]]
## Each array = scene index, values = property names from advanced_properties
## Only used in FULL mode
@export_multiline var spawn_scene_properties_json: String = "":
	set(value):
		spawn_scene_properties_json = value
		_parse_scene_properties_json()

## Apply advanced properties to all scenes (ignores spawn_scene_properties_advanced)
## Only used in FULL mode
@export var use_declarations_as_global: bool = false:
	set(value):
		use_declarations_as_global = value
		if spawner_core:
			spawner_core.use_declarations_as_global = value
	get:
		return spawner_core.use_declarations_as_global if spawner_core else use_declarations_as_global

## --- ENTITY TRACKING (delegated to core) ---

@export_group("Entity Tracking")
## Signal name to listen for on spawned entities (for death/destruction)
## When this signal is emitted, alive_count will decrement
## Used in FULL and TRACKED modes
@export var death_signal_name: String = "tree_exiting":
	set(value):
		death_signal_name = value
		if spawner_core:
			spawner_core.death_signal_name = value
	get:
		return spawner_core.death_signal_name if spawner_core else death_signal_name

## --- TIMING MODE SETTINGS ---

@export_group("Timing Mode")
## Current timing mode
@export var timing_mode: TimingMode = TimingMode.INTERVAL

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

## --- AUTO START ---

@export_group("Auto Start")
## Whether to automatically start spawning on _ready()
@export var auto_start: bool = false

## Delay before auto-start (seconds)
@export var auto_start_delay: float = 0.0

## --- GEOMETRY ---

@export_group("Spawn Geometry")
## Spawn at origin if no SpawnGeometry2D child found
@export var spawn_at_origin_if_no_geometry: bool = true

## --- STATE ---

## Whether spawner is currently active
var is_spawning: bool = false

## Whether spawner is paused
var is_paused: bool = false

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

## Core spawner component
var spawner_core: SpawnerCore = null

## Geometry component
var geometry: SpawnGeometry2D = null

## Label spawner for floating text system
var _label_spawner: LabelSpawner = null

## Floating text component for damage numbers
var _floating_text_component: FloatingTextComponent = null

## --- SIGNALS ---

## Emitted when an entity is spawned.[br]
## [param entity]: The spawned Node.[br]
## [param scene_index]: Index of spawn scene used (-1 if single scene).
signal entity_spawned(entity: Node, scene_index: int)

## Emitted when max_spawns limit is reached.
signal spawn_limit_reached()

## Emitted when spawning starts.
signal spawning_started()

## Emitted when spawning stops.
signal spawning_stopped()

## Emitted when spawning is paused.
signal spawning_paused()

## Emitted when spawning is resumed.
signal spawning_resumed()

## Emitted when a wave completes (WAVE mode only).[br]
## [param wave_number]: Wave number (0-indexed).
signal wave_completed(wave_number: int)

## Emitted when spawn list completes (LIST mode only).
signal list_completed()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	if not geometry:
		var found = get_node_or_null("SpawnGeometry2D")
		if not found:
			for child in get_children():
				if child is SpawnGeometry2D:
					found = child
					break
		
		if not found and not spawn_at_origin_if_no_geometry:
			warnings.append("No SpawnGeometry2D child found. Add SpawnGeometry2D as child or enable 'spawn_at_origin_if_no_geometry'.")
	
	return warnings


func _enter_tree() -> void:
	# Setup floating text system
	_label_spawner = LabelSpawner.new(get_parent(), 20)
	_label_spawner.configure_defaults(16, true, Color.BLACK, 2)
	_floating_text_component = FloatingTextComponent.new(self, get_parent(), _label_spawner)
	_floating_text_component.float_speed = 60.0
	_floating_text_component.duration = 1.2


func _ready() -> void:
	# Setup core and geometry
	_setup_spawner_core()
	_find_geometry()
	
	# Editor mode - only parse properties
	if Engine.is_editor_hint():
		_parse_scene_properties_json()
		return
	
	# Prepare spawn list if in LIST mode
	if timing_mode == TimingMode.LIST:
		_prepare_spawn_list()
	
	# Handle auto-start
	if auto_start:
		if auto_start_delay > 0.0:
			_waiting_for_auto_start = true
			_auto_start_timer = 0.0
		else:
			start_spawning()


func _process(delta: float) -> void:
	# Editor: just for tool updates
	if Engine.is_editor_hint():
		return

	# Update floating text animations
	if _floating_text_component:
		_floating_text_component.update(delta)
	
	# Handle auto-start delay
	if _waiting_for_auto_start:
		_auto_start_timer += delta
		if _auto_start_timer >= auto_start_delay:
			_waiting_for_auto_start = false
			start_spawning()
		return
	
	# ADDED: Skip automatic spawning in manual mode
	if manual_mode:
		return
	
	if not is_spawning or is_paused:
		return
	
	# Check spawn limits
	if spawner_core and spawner_core.max_spawns >= 0 and spawner_core.total_spawned >= spawner_core.max_spawns:
		stop_spawning()
		spawn_limit_reached.emit()
		return
	
	# Update spawn logic based on timing mode
	match timing_mode:
		TimingMode.INTERVAL:
			_update_interval_mode(delta)
		TimingMode.WAVE:
			_update_wave_mode(delta)
		TimingMode.LIST:
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
	
	if timing_mode == TimingMode.LIST:
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


## Manually spawn entity at calculated position.[br]
## [param scene_index]: Index of scene to spawn (-1 = use spawn_scene or random).[br]
## [param position_override]: Optional position override (null = use spawn area).[br>
## [return]: Spawned entity Node, or null if failed.
func spawn_entity(scene_index: int = -1, position_override: Variant = null) -> Node:
	if not spawner_core:
		push_warning("SpawnerComponent2D: spawner_core not initialized")
		return null
	
	var pos: Vector2
	var direction: float = 0.0
	
	if position_override != null:
		pos = position_override
	else:
		pos = _get_spawn_position()
		# Get direction if geometry supports it
		if geometry and geometry.apply_spawn_direction:
			direction = geometry.get_spawn_direction()
	
	var entity = spawner_core.spawn(pos, scene_index)
	
	# Apply direction if entity was spawned and geometry wants direction applied
	if entity and geometry and geometry.apply_spawn_direction:
		_apply_direction_to_entity(entity, direction)
	
	# Increment sequential index if using LINE with SEQUENTIAL mode
	if geometry and geometry.area_shape == SpawnGeometry2D.AreaShape.LINE:
		if geometry.line_distribution == SpawnGeometry2D.LineDistribution.SEQUENTIAL:
			geometry.line_current_index += 1
	
	return entity


## Register a service for dependency injection.[br]
## Services are shared references injected into spawned entities.[br]
## [param service_name]: Property name on entity (supports dot notation).[br]
## [param service]: The service instance (usually RefCounted or Node).
func register_service(service_name: String, service: Variant) -> void:
	if spawner_core:
		spawner_core.register_service(service_name, service)


## Unregister a service.[br]
## [param service_name]: Service name to remove.
func unregister_service(service_name: String) -> void:
	if spawner_core:
		spawner_core.unregister_service(service_name)


## Clear all registered services.
func clear_services() -> void:
	if spawner_core:
		spawner_core.clear_services()


## Set spawn list for LIST mode.[br]
## [param list]: Dictionary { delay: [scene_indices], ... }
func set_spawn_list(list: Dictionary) -> void:
	spawn_list = list
	_prepare_spawn_list()


## Reset counters and timers.
func reset() -> void:
	if spawner_core:
		spawner_core.reset()
	_spawn_timer = 0.0
	_list_index = 0
	_current_delay = 0.0
	
	# Reset geometry sequential index
	if geometry:
		geometry.reset_line_index()


## Get number of currently alive entities.[br]
## [return]: Count of alive entities.
func get_alive_count() -> int:
	return spawner_core.get_alive_count() if spawner_core else 0


## Get total spawned entities in lifetime.[br]
## [return]: Total spawn count.
func get_total_spawned() -> int:
	return spawner_core.get_total_spawned() if spawner_core else 0


## Check if max alive limit is reached.[br]
## [return]: true if at or over limit.
func is_alive_limit_reached() -> bool:
	return spawner_core.is_alive_limit_reached() if spawner_core else false


## Get spawner statistics.[br]
## [return]: Dictionary with stats.
func get_stats() -> Dictionary:
	var stats = spawner_core.get_stats() if spawner_core else {}
	stats.merge({
		"is_spawning": is_spawning,
		"is_paused": is_paused,
		"timing_mode": TimingMode.keys()[timing_mode],
		"has_geometry": geometry != null
	})
	return stats


## --- INTERNAL SETUP ---

func _setup_spawner_core() -> void:
	# Create temp core to avoid get loopback
	var temp_core = SpawnerCore.new(self, spawn_parent if spawn_parent else self)
	
	# Set initial properties from exports
	temp_core.spawn_scene = spawn_scene
	temp_core.spawn_scenes = spawn_scenes
	temp_core.spawn_mode = spawn_mode
	temp_core.max_alive = max_alive
	temp_core.max_spawns = max_spawns
	temp_core.spawn_properties = spawn_properties
	temp_core.spawn_scene_properties = spawn_scene_properties
	temp_core.advanced_properties = advanced_properties
	temp_core.use_declarations_as_global = use_declarations_as_global
	temp_core.death_signal_name = death_signal_name
	
	# Register services
	if _label_spawner:
		temp_core.register_service("label_spawner", _label_spawner)
	if _floating_text_component:
		temp_core.register_service("floating_text_component", _floating_text_component)
	
	spawner_core = temp_core


func _find_geometry() -> void:
	# Look for SpawnGeometry2D child
	geometry = get_node_or_null("SpawnGeometry2D")
	
	if not geometry:
		for child in get_children():
			if child is SpawnGeometry2D:
				geometry = child
				break
	
	if not geometry and not spawn_at_origin_if_no_geometry:
		push_warning("SpawnerComponent2D: No SpawnGeometry2D child found, spawning at origin")


## --- MANUAL MODE---

## Spawn a specific number of entities immediately (manual control).[br]
## Does not affect is_spawning state or timers.[br]
## [param count]: Number of entities to spawn.[br]
## [param ignore_limits]: If true, bypass max_alive check.
func spawn_wave_manual(count: int, ignore_limits: bool = false) -> int:
	var spawned := 0
	for i in range(count):
		if not ignore_limits and is_alive_limit_reached():
			break
		if spawn_entity() != null:
			spawned += 1
	return spawned

## Spawn entities over time (manual burst spawning).[br]
## Useful for spreading spawns across frames.[br]
## [param count]: Total entities to spawn.[br]
## [param duration]: Time to spread spawns over (seconds).[br]
## [param ignore_limits]: If true, bypass max_alive check.
func spawn_wave_over_time(count: int, duration: float, ignore_limits: bool = false) -> void:
	if count <= 0:
		return
	
	var interval = duration / float(count)
	for i in range(count):
		if not ignore_limits and is_alive_limit_reached():
			break
		
		# Spawn after delay
		await get_tree().create_timer(interval).timeout
		spawn_entity()


## Enable manual mode (stops automatic spawning)
func set_manual_mode(enabled: bool) -> void:
	manual_mode = enabled
	if manual_mode and is_spawning:
		# Pause automatic spawning but keep is_spawning flag
		is_paused = true


## Check if in manual mode
func is_manual_mode() -> bool:
	return manual_mode

## --- TIMING MODE UPDATES ---

## Update INTERVAL spawn mode.
func _update_interval_mode(delta: float) -> void:
	_spawn_timer += delta
	
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		
		if is_alive_limit_reached():
			return
		
		for i in range(entities_per_spawn):
			if is_alive_limit_reached():
				break
			spawn_entity()


## Update WAVE spawn mode.
func _update_wave_mode(delta: float) -> void:
	_spawn_timer += delta
	
	if _spawn_timer >= wave_interval:
		_spawn_timer = 0.0
		
		if is_alive_limit_reached():
			return
		
		var spawned := 0
		for i in range(wave_size):
			if is_alive_limit_reached():
				break
			spawn_entity()
			spawned += 1
		
		if spawned > 0:
			var wave_num := floori(get_total_spawned() / float(wave_size))
			wave_completed.emit(wave_num)


## Update LIST spawn mode.
func _update_list_mode(delta: float) -> void:
	if _list_index >= _sorted_delays.size():
		stop_spawning()
		list_completed.emit()
		return
	
	_current_delay += delta
	
	var target_delay: float = _sorted_delays[_list_index]
	
	if _current_delay >= target_delay:
		var scene_indices: Array = spawn_list[target_delay]
		
		for scene_idx in scene_indices:
			if is_alive_limit_reached():
				break
			spawn_entity(scene_idx)
		
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


## --- POSITION CALCULATION ---

## Calculate spawn position based on geometry or origin.[br]
## [return]: Global position Vector2.
func _get_spawn_position() -> Vector2:
	if geometry:
		var local_pos = geometry.get_spawn_position()
		return global_position + local_pos
	
	# No geometry - spawn at origin or self position
	return global_position if spawn_at_origin_if_no_geometry else Vector2.ZERO


## Apply direction to spawned entity.[br]
## [param entity]: The spawned entity.[br]
## [param direction]: Direction angle in radians.
func _apply_direction_to_entity(entity: Node, direction: float) -> void:
	# Try different common direction properties
	if "rotation" in entity:
		entity.rotation = direction
	elif "direction" in entity and entity.direction is Vector2:
		entity.direction = Vector2.from_angle(direction)
	elif "velocity" in entity and entity.velocity is Vector2:
		# Assume some default speed if velocity exists
		var speed = entity.velocity.length() if entity.velocity.length() > 0 else 100.0
		entity.velocity = Vector2.from_angle(direction) * speed
	elif "linear_velocity" in entity and entity.linear_velocity is Vector2:
		var speed = entity.linear_velocity.length() if entity.linear_velocity.length() > 0 else 100.0
		entity.linear_velocity = Vector2.from_angle(direction) * speed


## Parse JSON string into spawn_scene_properties_advanced array.
func _parse_scene_properties_json() -> void:
	if not spawner_core:
		return
	
	if spawn_scene_properties_json.is_empty():
		spawner_core.spawn_scene_properties_advanced.clear()
		return
	
	var json = JSON.new()
	var error = json.parse(spawn_scene_properties_json)
	
	if error != OK:
		push_error("SpawnerComponent2D: Failed to parse spawn_scene_properties_json at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return
	
	var data = json.data
	if not data is Array:
		push_error("SpawnerComponent2D: spawn_scene_properties_json must be an array")
		return
	
	# Convert to Array[Array] and validate
	spawner_core.spawn_scene_properties_advanced.clear()
	for scene_data in data:
		if scene_data is Array:
			var scene_props: Array = []
			for prop in scene_data:
				if prop is String:
					scene_props.append(prop)
				else:
					push_warning("SpawnerComponent2D: Property in scene data is not a string: %s" % str(prop))
			spawner_core.spawn_scene_properties_advanced.append(scene_props)
		else:
			push_warning("SpawnerComponent2D: Scene data is not an array: %s" % str(scene_data))
			spawner_core.spawn_scene_properties_advanced.append([])
