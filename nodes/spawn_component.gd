@tool
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
@export var area_shape: AreaShape = AreaShape.CIRCLE:
	set(value):
		area_shape = value
		queue_redraw()

## Where to spawn within area
@export var spawn_location: SpawnLocation = SpawnLocation.VOLUME:
	set(value):
		spawn_location = value
		queue_redraw()

## Center position of spawn area (local to this node)
@export var spawn_center: Vector2 = Vector2.ZERO:
	set(value):
		spawn_center = value
		queue_redraw()

## Circle: radius of spawn area
@export var spawn_radius: float = 100.0:
	set(value):
		spawn_radius = value
		queue_redraw()

## Rectangle: size of spawn area
@export var spawn_size: Vector2 = Vector2(200.0, 200.0):
	set(value):
		spawn_size = value
		queue_redraw()

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
@export var spawn_list: Dictionary[float, Array] = {}

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

## --- CUSTOM PROPERTIES ---

@export_group("Custom Properties")
## Properties to set on spawned entities { "property_name": value }
## Supports nested properties using dot notation: "health_component.max_health"
@export var spawn_properties: Dictionary[String, Variant] = {}

## Per-scene properties (indexed by spawn_scenes array index)
## These override spawn_properties for specific scenes
@export var spawn_scene_properties: Array[Dictionary] = []

@export_group("Advanced Properties")
## Advanced property value declarations: { "property_path": SpawnPropertyValue }
## Property path supports dot notation (e.g., "health_component.max_health")
@export var advanced_properties: Dictionary[String, SpawnPropertyValue] = {}

## Per-scene advanced property assignments (JSON format for easier editing)
## Format: [["prop1", "prop2"], ["prop3"], ["prop1", "prop3"]]
## Each array = scene index, values = property names from advanced_properties
@export_multiline var spawn_scene_properties_json: String = "":
	set(value):
		spawn_scene_properties_json = value
		_parse_scene_properties_json()

## Parsed array (don't edit directly, use spawn_scene_properties_json)
var spawn_scene_properties_advanced: Array[Array] = []

## Apply advanced properties to all scenes (ignores spawn_scene_properties_advanced)
@export var use_declarations_as_global: bool = false

## --- ENTITY TRACKING ---

@export_group("Entity Tracking")
## Signal name to listen for on spawned entities (for death/destruction)
## When this signal is emitted, alive_count will decrement
@export var death_signal_name: String = "tree_exiting"

## --- VISUAL HELPERS ---

@export_group("Visual Helpers")
## Show spawn area visualization in editor
@export var show_spawn_area: bool = true:
	set(value):
		show_spawn_area = value
		queue_redraw()

## Color of spawn area visualization
@export var spawn_area_color: Color = Color(0.0, 1.0, 0.0, 0.5):
	set(value):
		spawn_area_color = value
		queue_redraw()

## Show spawn center crosshair
@export var show_center: bool = true:
	set(value):
		show_center = value
		queue_redraw()

## Show preview spawn points
@export var show_spawn_preview: bool = false:
	set(value):
		show_spawn_preview = value
		queue_redraw()

## Number of preview spawn points to show
@export var preview_count: int = 10:
	set(value):
		preview_count = max(1, value)
		queue_redraw()

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

## Total entities spawned in lifetime (never decrements)
var total_spawned: int = 0

## Current number of alive entities
var alive_count: int = 0

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
	# Parse scene properties JSON if in editor
	if Engine.is_editor_hint():
		_parse_scene_properties_json()
		return
	
	# Only run spawning logic at runtime
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
	# Editor: just redraw if needed
	if Engine.is_editor_hint():
		return
	
	# Handle auto-start delay
	if _waiting_for_auto_start:
		_auto_start_timer += delta
		if _auto_start_timer >= auto_start_delay:
			_waiting_for_auto_start = false
			start_spawning()
		return
	
	if not is_spawning or is_paused:
		return
	
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


func _draw() -> void:
	# Only draw in editor
	if not Engine.is_editor_hint():
		return
	
	if not show_spawn_area:
		return
	
	# Draw spawn center crosshair
	if show_center:
		var cross_size := 10.0
		draw_line(
			spawn_center + Vector2(-cross_size, 0),
			spawn_center + Vector2(cross_size, 0),
			spawn_area_color,
			2.0
		)
		draw_line(
			spawn_center + Vector2(0, -cross_size),
			spawn_center + Vector2(0, cross_size),
			spawn_area_color,
			2.0
		)
	
	# Draw spawn area based on shape
	match area_shape:
		AreaShape.POINT:
			_draw_point_area()
		AreaShape.CIRCLE:
			_draw_circle_area()
		AreaShape.RECTANGLE:
			_draw_rectangle_area()
	
	# Draw spawn preview points
	if show_spawn_preview:
		_draw_spawn_preview()


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
	
	# Apply custom properties
	_apply_entity_properties(entity, scene_index)
	
	# Connect death signal for tracking
	_connect_death_signal(entity)
	
	# Update counters
	alive_count += 1
	total_spawned += 1
	
	# Emit signal
	entity_spawned.emit(entity, scene_index)
	
	return entity


## Reset spawn counters.
func reset() -> void:
	total_spawned = 0
	alive_count = 0
	_spawn_timer = 0.0
	_list_index = 0
	_current_delay = 0.0


## Get number of currently alive entities.[br]
## [return]: Count of alive entities.
func get_alive_count() -> int:
	return alive_count


## Get total spawned entities in lifetime.[br]
## [return]: Total spawn count.
func get_total_spawned() -> int:
	return total_spawned


## Check if max alive limit is reached.[br]
## [return]: true if at or over limit.
func is_alive_limit_reached() -> bool:
	if max_alive < 0:
		return false
	return alive_count >= max_alive


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


## Set custom properties to apply to spawned entities.[br]
## [param properties]: Dictionary of property names and values.[br]
## Supports nested properties with dot notation (e.g., "component.property")
func set_spawn_properties(properties: Dictionary) -> void:
	spawn_properties = properties


## Add/update a single spawn property.[br]
## [param property_path]: Property name or path (supports dot notation).[br]
## [param value]: Value to set.
func set_spawn_property(property_path: String, value: Variant) -> void:
	spawn_properties[property_path] = value


## Remove a spawn property.[br]
## [param property_path]: Property name or path to remove.
func remove_spawn_property(property_path: String) -> void:
	spawn_properties.erase(property_path)


## Clear all spawn properties.
func clear_spawn_properties() -> void:
	spawn_properties.clear()


## Set properties for a specific scene index.[br]
## [param scene_index]: Index in spawn_scenes array.[br]
## [param properties]: Dictionary of properties for this scene.
func set_scene_properties(scene_index: int, properties: Dictionary) -> void:
	# Expand array if needed
	while spawn_scene_properties.size() <= scene_index:
		spawn_scene_properties.append({})
	spawn_scene_properties[scene_index] = properties


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
			var wave_num := floori(total_spawned / float(wave_size))
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


## Apply properties to spawned entity.[br]
## This function handles property assignment and can be extended for features like min/max ranges.
func _apply_entity_properties(entity: Node, scene_index: int) -> void:
	# 1. Apply advanced properties first (highest priority)
	_apply_advanced_properties(entity, scene_index)
	
	# 2. Apply global properties
	for property_path in spawn_properties.keys():
		var value = spawn_properties[property_path]
		_set_property_on_entity(entity, property_path, value)
	
	# 3. Apply scene-specific properties (override global)
	if scene_index >= 0 and scene_index < spawn_scene_properties.size():
		var scene_props := spawn_scene_properties[scene_index]
		for property_path in scene_props.keys():
			var value = scene_props[property_path]
			_set_property_on_entity(entity, property_path, value)


## Set property on entity with support for nested paths.[br]
## This is the core property assignment function that can be extended later.
func _set_property_on_entity(entity: Node, property_path: String, value: Variant) -> void:
	_set_nested_property(entity, property_path, value)


## Apply advanced properties to entity.
func _apply_advanced_properties(entity: Node, scene_index: int) -> void:
	if advanced_properties.is_empty():
		return
	
	var properties_to_apply: Array = []
	
	# Determine which properties to apply
	if use_declarations_as_global:
		# Use all advanced properties
		properties_to_apply = advanced_properties.keys()
	else:
		# Use scene-specific properties
		if scene_index >= 0 and scene_index < spawn_scene_properties_advanced.size():
			var scene_props = spawn_scene_properties_advanced[scene_index]
			if scene_props is Array:
				properties_to_apply = scene_props
	
	# Apply selected properties
	for prop_name in properties_to_apply:
		if not advanced_properties.has(prop_name):
			push_warning("SpawnPropertyValue '%s' not found in advanced_properties" % prop_name)
			continue
		
		var prop_value: SpawnPropertyValue = advanced_properties[prop_name]
		if not prop_value:
			continue
		
		# Get context value based on property's context source
		var x_value := _get_context_value(prop_value.context_source)
		
		# Get the generated value
		var value = prop_value.get_value(x_value)
		
		# Set the property (prop_name is already the target path)
		_set_nested_property(entity, prop_name, value)


## Get context value for advanced properties based on source type.
func _get_context_value(source: SpawnPropertyValue.ContextSource) -> float:
	match source:
		SpawnPropertyValue.ContextSource.SPAWN_INDEX:
			return float(total_spawned)
		
		SpawnPropertyValue.ContextSource.SPAWN_PROGRESS:
			if max_spawns > 0:
				return clamp(float(total_spawned) / float(max_spawns), 0.0, 1.0)
			return 0.0
		
		SpawnPropertyValue.ContextSource.ALIVE_COUNT:
			return float(alive_count)
		
		SpawnPropertyValue.ContextSource.TIME_ELAPSED:
			return _spawn_timer
		
		SpawnPropertyValue.ContextSource.WAVE_NUMBER:
			if spawn_mode == SpawnMode.WAVE and wave_size > 0:
				return float(floori(total_spawned / float(wave_size)))
			return 0.0
		
		SpawnPropertyValue.ContextSource.RANDOM:
			return randf()
		
		_:
			return 0.0


## Set nested property using dot notation.[br]
## Example: "health_component.max_health" will set entity.health_component.max_health
func _set_nested_property(entity: Node, property_path: String, value: Variant) -> void:
	var parts := property_path.split(".")
	var current: Variant = entity
	
	# Navigate to the nested object
	for i in range(parts.size() - 1):
		var part := parts[i]
		if current.get(part) == null:
			push_warning("SpawnerComponent: Property path '%s' not found (stopped at '%s')" % [property_path, part])
			return
		current = current.get(part)
	
	# Set the final property
	var final_property := parts[-1]
	if current.get(final_property) == null and not (current is Node and current.has_method("set")):
		push_warning("SpawnerComponent: Property '%s' not found on '%s'" % [final_property, current])
		return
	
	current.set(final_property, value)


## Connect to entity's death signal for tracking.
func _connect_death_signal(entity: Node) -> void:
	if death_signal_name.is_empty():
		return
	
	if not entity.has_signal(death_signal_name):
		push_warning("SpawnerComponent: Entity does not have signal '%s'" % death_signal_name)
		return
	
	entity.connect(death_signal_name, _on_entity_died)


## Callback when entity dies/is destroyed.
func _on_entity_died() -> void:
	alive_count = max(0, alive_count - 1)


## Check if spawn limit reached.[br]
## [return]: true if any limit is reached.
func _is_spawn_limit_reached() -> bool:
	# Check max spawns
	if max_spawns >= 0 and total_spawned >= max_spawns:
		spawn_limit_reached.emit()
		return true
	
	# Check max alive
	if is_alive_limit_reached():
		return true
	
	return false


## Draw point spawn area.
func _draw_point_area() -> void:
	var point_size := 8.0
	draw_circle(spawn_center, point_size, spawn_area_color)


## Draw circle spawn area.
func _draw_circle_area() -> void:
	var points := 64
	var step := TAU / points
	
	match spawn_location:
		SpawnLocation.VOLUME:
			# Draw filled circle
			draw_circle(spawn_center, spawn_radius, Color(spawn_area_color, spawn_area_color.a * 0.3))
			# Draw outline
			for i in range(points):
				var angle1 := i * step
				var angle2 := (i + 1) * step
				var p1 := spawn_center + Vector2(cos(angle1), sin(angle1)) * spawn_radius
				var p2 := spawn_center + Vector2(cos(angle2), sin(angle2)) * spawn_radius
				draw_line(p1, p2, spawn_area_color, 2.0)
		
		SpawnLocation.EDGE:
			# Draw thick edge
			for i in range(points):
				var angle1 := i * step
				var angle2 := (i + 1) * step
				var p1 := spawn_center + Vector2(cos(angle1), sin(angle1)) * spawn_radius
				var p2 := spawn_center + Vector2(cos(angle2), sin(angle2)) * spawn_radius
				draw_line(p1, p2, spawn_area_color, 4.0)


## Draw rectangle spawn area.
func _draw_rectangle_area() -> void:
	var half_size := spawn_size / 2.0
	var rect := Rect2(spawn_center - half_size, spawn_size)
	
	match spawn_location:
		SpawnLocation.VOLUME:
			# Draw filled rectangle
			draw_rect(rect, Color(spawn_area_color, spawn_area_color.a * 0.3))
			# Draw outline
			draw_rect(rect, spawn_area_color, false, 2.0)
		
		SpawnLocation.EDGE:
			# Draw thick edges
			var tl := rect.position
			var tr := rect.position + Vector2(rect.size.x, 0)
			var br := rect.position + rect.size
			var bl := rect.position + Vector2(0, rect.size.y)
			draw_line(tl, tr, spawn_area_color, 4.0)
			draw_line(tr, br, spawn_area_color, 4.0)
			draw_line(br, bl, spawn_area_color, 4.0)
			draw_line(bl, tl, spawn_area_color, 4.0)
		
		SpawnLocation.CORNERS:
			# Draw corner markers
			var corner_size := 10.0
			var corners := [
				rect.position,
				rect.position + Vector2(rect.size.x, 0),
				rect.position + rect.size,
				rect.position + Vector2(0, rect.size.y)
			]
			for corner in corners:
				draw_circle(corner, corner_size, spawn_area_color)


## Draw preview spawn points.
func _draw_spawn_preview() -> void:
	var point_color := Color(spawn_area_color.r, spawn_area_color.g, spawn_area_color.b, 0.8)
	var point_size := 4.0
	
	for i in range(preview_count):
		var pos := _get_spawn_position() - global_position
		draw_circle(pos, point_size, point_color)


## Get spawner statistics.[br]
## [return]: Dictionary with stats.
func get_stats() -> Dictionary:
	return {
		"is_spawning": is_spawning,
		"is_paused": is_paused,
		"total_spawned": total_spawned,
		"alive_count": alive_count,
		"spawn_mode": SpawnMode.keys()[spawn_mode],
		"area_shape": AreaShape.keys()[area_shape],
		"spawn_location": SpawnLocation.keys()[spawn_location]
	}


## Parse JSON string into spawn_scene_properties_advanced array.
func _parse_scene_properties_json() -> void:
	if spawn_scene_properties_json.is_empty():
		spawn_scene_properties_advanced.clear()
		return
	
	var json = JSON.new()
	var error = json.parse(spawn_scene_properties_json)
	
	if error != OK:
		push_error("SpawnerComponent: Failed to parse spawn_scene_properties_json at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return
	
	var data = json.data
	if not data is Array:
		push_error("SpawnerComponent: spawn_scene_properties_json must be an array")
		return
	
	# Convert to Array[Array] and validate
	spawn_scene_properties_advanced.clear()
	for scene_data in data:
		if scene_data is Array:
			var scene_props: Array = []
			for prop in scene_data:
				if prop is String:
					scene_props.append(prop)
				else:
					push_warning("SpawnerComponent: Property in scene data is not a string: %s" % str(prop))
			spawn_scene_properties_advanced.append(scene_props)
		else:
			push_warning("SpawnerComponent: Scene data is not an array: %s" % str(scene_data))
			spawn_scene_properties_advanced.append([])
