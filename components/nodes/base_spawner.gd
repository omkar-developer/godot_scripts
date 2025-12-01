class_name BaseSpawner
extends Node2D

## Base spawner class handling scene management, spawning, and entity tracking.
## Can be used standalone or extended for spatial spawning patterns.

## Spawn configuration modes
enum SpawnMode {
	FULL,           ## Full feature set: tracking, properties, services, limits
	TRACKED,        ## Tracking + limits only, no property/service injection
	FAST            ## Minimal overhead: just instantiate and add to tree
}

## --- SPAWN SCENES ---

@export_group("Spawn Scenes")
## Single spawn scene (used when spawn_scenes array is empty)
@export var spawn_scene: PackedScene = null

## Multiple spawn scenes (takes priority over spawn_scene if not empty)
@export var spawn_scenes: Array[PackedScene] = []

## --- SPAWN MODE ---

@export_group("Spawn Configuration")
## Spawn mode affects what features are enabled
@export var spawn_mode: SpawnMode = SpawnMode.FULL

## --- SPAWN LIMITS ---

@export_group("Spawn Limits")
## Maximum entities alive at once (-1 = unlimited)
@export var max_alive: int = -1

## Maximum total spawns (-1 = unlimited)
@export var max_spawns: int = -1

## --- SPAWN PARENT ---

@export_group("Spawn Target")
## Where to add spawned entities (null = this node)
@export var spawn_parent: Node = null

## --- CUSTOM PROPERTIES ---

@export_group("Custom Properties")
## Properties to set on spawned entities { "property_name": value }
## Supports nested properties using dot notation: "health_component.max_health"
## Only used in FULL mode
@export var spawn_properties: Dictionary[String, Variant] = {}

## Per-scene properties (indexed by spawn_scenes array index)
## These override spawn_properties for specific scenes
## Only used in FULL mode
@export var spawn_scene_properties: Array[Dictionary] = []

@export_group("Advanced Properties")
## Advanced property value declarations: { "property_path": SpawnPropertyValue }
## Property path supports dot notation (e.g., "health_component.max_health")
## Only used in FULL mode
@export var advanced_properties: Dictionary[String, SpawnPropertyValue] = {}

## Per-scene advanced property assignments (JSON format for easier editing)
## Format: [["prop1", "prop2"], ["prop3"], ["prop1", "prop3"]]
## Each array = scene index, values = property names from advanced_properties
## Only used in FULL mode
@export_multiline var spawn_scene_properties_json: String = "":
	set(value):
		spawn_scene_properties_json = value
		_parse_scene_properties_json()

## Parsed array (don't edit directly, use spawn_scene_properties_json)
var spawn_scene_properties_advanced: Array[Array] = []

## Apply advanced properties to all scenes (ignores spawn_scene_properties_advanced)
## Only used in FULL mode
@export var use_declarations_as_global: bool = false

## --- ENTITY TRACKING ---

@export_group("Entity Tracking")
## Signal name to listen for on spawned entities (for death/destruction)
## When this signal is emitted, alive_count will decrement
## Used in FULL and TRACKED modes
@export var death_signal_name: String = "tree_exiting"

## --- STATE ---

## Total entities spawned in lifetime (never decrements)
var total_spawned: int = 0

## Current number of alive entities (only tracked in FULL/TRACKED modes)
var alive_count: int = 0

## Injectable services (shared references injected into entities)
## Example: { "label_spawner": label_spawner_instance }
## Only used in FULL mode
var injectable_services: Dictionary[String, Variant] = {}

## --- SIGNALS ---

## Emitted when an entity is spawned.[br]
## [param entity]: The spawned Node.[br]
## [param scene_index]: Index of spawn scene used (-1 if single scene).
signal entity_spawned(entity: Node, scene_index: int)

## Emitted when max_spawns limit is reached.
signal spawn_limit_reached()


func _ready() -> void:
	# Parse scene properties JSON if in editor
	if Engine.is_editor_hint():
		_parse_scene_properties_json()


## Spawn an entity at the given position (full feature set).[br]
## [param position]: Global position to spawn at (null = no position set).[br]
## [param scene_index]: Index of scene to spawn (-1 = use spawn_scene or random).[br]
## [param parent]: Optional parent override (null = use spawn_parent or self).[br]
## [return]: Spawned entity Node, or null if failed.
func spawn(position: Variant = null, scene_index: int = -1, parent: Node = null) -> Node:
	# Check spawn limits
	if _is_spawn_limit_reached():
		return null
	
	var scene := _get_spawn_scene(scene_index)
	if not scene:
		push_warning("BaseSpawner: No spawn scene available")
		return null
	
	var entity = scene.instantiate()
	if not entity:
		push_warning("BaseSpawner: Failed to instantiate scene")
		return null
	
	var target_parent := _resolve_spawn_parent(parent)
	if not target_parent:
		push_warning("BaseSpawner: No spawn parent available")
		entity.queue_free()
		return null
	
	# Set position if entity is Node2D and position provided
	if entity is Node2D and position != null and position is Vector2:
		entity.global_position = position
	
	# Apply features based on spawn mode
	match spawn_mode:
		SpawnMode.FULL:
			_inject_services(entity)
			_apply_entity_properties(entity, scene_index)
			target_parent.add_child(entity)
			_connect_death_signal(entity)
			alive_count += 1
		
		SpawnMode.TRACKED:
			target_parent.add_child(entity)
			_connect_death_signal(entity)
			alive_count += 1
		
		SpawnMode.FAST:
			target_parent.add_child(entity)
	
	# Update counters
	total_spawned += 1
	
	# Emit signal
	entity_spawned.emit(entity, scene_index)
	
	return entity


## Fast spawn - bypasses all property injection, services, and most checks.[br]
## Only does: instantiate -> set position -> add to tree.[br]
## No tracking, no limits checked (use with caution).[br]
## [param position]: Global position (null = no position set).[br]
## [param scene_index]: Scene index (-1 = auto).[br]
## [param parent]: Parent override (null = use default).[br]
## [return]: Spawned entity or null.
func spawn_fast(position: Variant = null, scene_index: int = -1, parent: Node = null) -> Node:
	var scene := _get_spawn_scene(scene_index)
	if not scene:
		return null
	
	var entity = scene.instantiate()
	if not entity:
		return null
	
	if entity is Node2D and position != null and position is Vector2:
		entity.global_position = position
	
	var target_parent := _resolve_spawn_parent(parent)
	if target_parent:
		target_parent.add_child(entity)
		return entity
	
	entity.queue_free()
	return null


## Register a service for dependency injection.[br]
## Services are shared references injected into spawned entities.[br]
## [param service_name]: Property name on entity (supports dot notation).[br]
## [param service]: The service instance (usually RefCounted or Node).
func register_service(service_name: String, service: Variant) -> void:
	injectable_services[service_name] = service


## Unregister a service.[br]
## [param service_name]: Service name to remove.
func unregister_service(service_name: String) -> void:
	injectable_services.erase(service_name)


## Clear all registered services.
func clear_services() -> void:
	injectable_services.clear()


## Reset spawn counters.
func reset() -> void:
	total_spawned = 0
	alive_count = 0


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


## Get spawner statistics.[br]
## [return]: Dictionary with stats.
func get_stats() -> Dictionary:
	return {
		"spawn_mode": SpawnMode.keys()[spawn_mode],
		"total_spawned": total_spawned,
		"alive_count": alive_count,
		"has_spawn_scene": spawn_scene != null,
		"spawn_scenes_count": spawn_scenes.size(),
		"registered_services": injectable_services.size()
	}


## --- INTERNAL METHODS ---

## Resolve which parent to use for spawning.
func _resolve_spawn_parent(parent_override: Node = null) -> Node:
	if parent_override:
		return parent_override
	if spawn_parent:
		return spawn_parent
	return self


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


## Inject services into entity (before properties).
func _inject_services(entity: Node) -> void:
	for service_name in injectable_services:
		_set_nested_property(entity, service_name, injectable_services[service_name])


## Apply properties to spawned entity.
func _apply_entity_properties(entity: Node, scene_index: int) -> void:
	# 1. Apply advanced properties first (highest priority)
	_apply_advanced_properties(entity, scene_index)
	
	# 2. Apply global properties
	for property_path in spawn_properties.keys():
		var value = spawn_properties[property_path]
		_set_nested_property(entity, property_path, value)
	
	# 3. Apply scene-specific properties (override global)
	if scene_index >= 0 and scene_index < spawn_scene_properties.size():
		var scene_props := spawn_scene_properties[scene_index]
		for property_path in scene_props.keys():
			var value = scene_props[property_path]
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
		
		# Set the property
		_set_nested_property(entity, prop_name, value)


## Get context value for advanced properties - override in subclasses for additional context.
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
		
		SpawnPropertyValue.ContextSource.RANDOM:
			return randf()
		
		_:
			return 0.0


## Set nested property using dot notation.
func _set_nested_property(entity: Node, property_path: String, value: Variant) -> void:
	var parts := property_path.split(".")
	var current: Variant = entity
	
	# Navigate to the nested object
	for i in range(parts.size() - 1):
		var part := parts[i]
		if current.get(part) == null:
			push_warning("BaseSpawner: Property path '%s' not found (stopped at '%s')" % [property_path, part])
			return
		current = current.get(part)
	
	# Set the final property
	var final_property := parts[-1]
	if current.get(final_property) == null and not (current is Node and current.has_method("set")):
		push_warning("BaseSpawner: Property '%s' not found on '%s'" % [final_property, current])
		return
	
	current.set(final_property, value)


## Connect to entity's death signal for tracking.
func _connect_death_signal(entity: Node) -> void:
	if death_signal_name.is_empty():
		return
	
	if not entity.has_signal(death_signal_name):
		push_warning("BaseSpawner: Entity does not have signal '%s'" % death_signal_name)
		return
	
	entity.connect(death_signal_name, Callable(self, "_on_entity_died"), CONNECT_ONE_SHOT)


## Callback when entity dies/is destroyed.
func _on_entity_died() -> void:
	alive_count = max(0, alive_count - 1)


## Check if spawn limit reached.
func _is_spawn_limit_reached() -> bool:
	# Check max spawns
	if max_spawns >= 0 and total_spawned >= max_spawns:
		spawn_limit_reached.emit()
		return true
	
	# Check max alive
	if is_alive_limit_reached():
		return true
	
	return false


## Parse JSON string into spawn_scene_properties_advanced array.
func _parse_scene_properties_json() -> void:
	if spawn_scene_properties_json.is_empty():
		spawn_scene_properties_advanced.clear()
		return
	
	var json = JSON.new()
	var error = json.parse(spawn_scene_properties_json)
	
	if error != OK:
		push_error("BaseSpawner: Failed to parse spawn_scene_properties_json at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return
	
	var data = json.data
	if not data is Array:
		push_error("BaseSpawner: spawn_scene_properties_json must be an array")
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
					push_warning("BaseSpawner: Property in scene data is not a string: %s" % str(prop))
			spawn_scene_properties_advanced.append(scene_props)
		else:
			push_warning("BaseSpawner: Scene data is not an array: %s" % str(scene_data))
			spawn_scene_properties_advanced.append([])
