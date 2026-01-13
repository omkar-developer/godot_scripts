class_name SpawnerCore
extends RefCounted

## Core spawner logic handling scene management, spawning, and entity tracking.
## RefCounted component that can be used in any spatial context (2D/3D/UI).

## Spawn configuration modes
enum SpawnMode {
	FULL,           ## Full feature set: tracking, properties, services, limits
	TRACKED,        ## Tracking + limits only, no property/service injection
	FAST            ## Minimal overhead: just instantiate and add to tree
}

## --- SPAWN SCENES ---

## Single spawn scene (used when spawn_scenes array is empty)
var spawn_scene: PackedScene = null

## Multiple spawn scenes (takes priority over spawn_scene if not empty)
var spawn_scenes: Array[PackedScene] = []

## --- SPAWN MODE ---

## Spawn mode affects what features are enabled
var spawn_mode: SpawnMode = SpawnMode.FULL

## --- SPAWN LIMITS ---

## Maximum entities alive at once (-1 = unlimited)
var max_alive: int = -1

## Maximum total spawns (-1 = unlimited)
var max_spawns: int = -1

## --- SPAWN PARENT ---

## Where to add spawned entities
var spawn_parent: Node = null

## --- CUSTOM PROPERTIES ---

## Properties to set on spawned entities { "property_name": value }
## Supports nested properties using dot notation: "health_component.max_health"
## Only used in FULL mode
var spawn_properties: Dictionary[String, Variant] = {}

## Per-scene properties (indexed by spawn_scenes array index)
## These override spawn_properties for specific scenes
## Only used in FULL mode
var spawn_scene_properties: Array[Dictionary] = []

## Advanced property value declarations: { "property_path": SpawnPropertyValue }
## Property path supports dot notation (e.g., "health_component.max_health")
## Only used in FULL mode
var advanced_properties: Dictionary[String, SpawnPropertyValue] = {}

## Per-scene advanced property assignments
## Each array = scene index, values = property names from advanced_properties
## Only used in FULL mode
var spawn_scene_properties_advanced: Array[Array] = []

## Apply advanced properties to all scenes (ignores spawn_scene_properties_advanced)
## Only used in FULL mode
var use_declarations_as_global: bool = false

## --- ENTITY TRACKING ---

## Signal name to listen for on spawned entities (for death/destruction)
## When this signal is emitted, alive_count will decrement
## Used in FULL and TRACKED modes
var death_signal_name: String = "tree_exiting"

## --- STATE ---

## Total entities spawned in lifetime (never decrements)
var total_spawned: int = 0

## Current number of alive entities (only tracked in FULL/TRACKED modes)
var alive_count: int = 0

## Injectable services (shared references injected into entities)
## Example: { "label_spawner": label_spawner_instance }
## Only used in FULL mode
var injectable_services: Dictionary = {}

## --- SIGNALS ---

## Emitted when an entity is spawned.[br]
## [param entity]: The spawned Node.[br]
## [param scene_index]: Index of spawn scene used (-1 if single scene).
signal entity_spawned(entity: Node, scene_index: int)

## Emitted when max_spawns limit is reached.
signal spawn_limit_reached()

## Owner node (for signal emission context)
var _owner: Node = null


## Constructor[br]
## [param owner]: Owner node for signal context.[br]
## [param parent]: Default spawn parent node.
func _init(owner: Node, parent: Node) -> void:
	_owner = owner
	spawn_parent = parent


## Spawn an entity at the given position (full feature set).[br]
## [param position]: Global position to spawn at (null = no position set).[br]
## [param scene_index]: Index of scene to spawn (-1 = use spawn_scene or random).[br]
## [param parent]: Optional parent override (null = use spawn_parent).[br]
## [return]: Spawned entity Node, or null if failed.
func spawn(position: Variant = null, scene_index: int = -1, parent: Node = null) -> Node:
	# Check spawn limits
	if _is_spawn_limit_reached():
		return null
	
	var scene := _get_spawn_scene(scene_index)
	if not scene:
		push_warning("SpawnerCore: No spawn scene available")
		return null
	
	var entity = scene.instantiate()
	if not entity:
		push_warning("SpawnerCore: Failed to instantiate scene")
		return null
	
	var target_parent := parent if parent else spawn_parent
	if not target_parent:
		push_warning("SpawnerCore: No spawn parent available")
		entity.queue_free()
		return null
	
	# Set position if entity is Node2D/Node3D and position provided
	if position != null:
		if entity is Node2D and position is Vector2:
			entity.global_position = position
		elif entity is Node3D and position is Vector3:
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
	if _owner:		
		_owner.emit_signal("entity_spawned", entity, scene_index)
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
	
	if position != null:
		if entity is Node2D and position is Vector2:
			entity.global_position = position
		elif entity is Node3D and position is Vector3:
			entity.global_position = position
	
	var target_parent := parent if parent else spawn_parent
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


## Add a spawn scene to the list.[br]
## [param scene]: PackedScene to add.[br]
## [return]: Index of added scene.
func add_spawn_scene(scene: PackedScene) -> int:
	spawn_scenes.append(scene)
	return spawn_scenes.size() - 1


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


## Get context value for advanced properties - can be extended by component wrapper.[br]
## [param source]: Context source enum value.[br]
## [return]: Computed context value.
func get_context_value(source: int) -> float:
	# SpawnPropertyValue.ContextSource enum values
	const SPAWN_INDEX = 0
	const SPAWN_PROGRESS = 1
	const ALIVE_COUNT = 2
	const RANDOM = 3
	
	match source:
		SPAWN_INDEX:
			return float(total_spawned)
		
		SPAWN_PROGRESS:
			if max_spawns > 0:
				return clamp(float(total_spawned) / float(max_spawns), 0.0, 1.0)
			return 0.0
		
		ALIVE_COUNT:
			return float(alive_count)
		
		RANDOM:
			return randf()
		
		_:
			return 0.0


## --- INTERNAL METHODS ---

## Get spawn scene based on index.[br]
## [param index]: Scene index (-1 = auto select).[br>
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
		var x_value := get_context_value(prop_value.context_source)
		
		# Get the generated value
		var value = prop_value.get_value(x_value)
		
		# Set the property
		_set_nested_property(entity, prop_name, value)


## Set nested property using dot notation.
func _set_nested_property(entity: Node, property_path: String, value: Variant) -> void:
	var parts := property_path.split(".")
	var current: Variant = entity
	
	# Navigate to the nested object
	for i in range(parts.size() - 1):
		var part := parts[i]
		if current.get(part) == null:
			push_warning("SpawnerCore: Property path '%s' not found (stopped at '%s')" % [property_path, part])
			return
		current = current.get(part)
	
	# Set the final property
	var final_property := parts[-1]
	if current.get(final_property) == null and not (current is Node and current.has_method("set")):
		push_warning("SpawnerCore: Property '%s' not found on '%s'" % [final_property, current])
		return
	
	current.set(final_property, value)


## Connect to entity's death signal for tracking.
func _connect_death_signal(entity: Node) -> void:
	if death_signal_name.is_empty():
		return
	
	if not entity.has_signal(death_signal_name):
		push_warning("SpawnerCore: Entity does not have signal '%s'" % death_signal_name)
		return
	
	entity.connect(death_signal_name, Callable(self, "_on_entity_died"), CONNECT_ONE_SHOT)


## Callback when entity dies/is destroyed.
func _on_entity_died() -> void:
	alive_count = max(0, alive_count - 1)


## Check if spawn limit reached.
func _is_spawn_limit_reached() -> bool:
	# Check max spawns
	if max_spawns >= 0 and total_spawned >= max_spawns:
		if _owner:
			_owner.emit_signal("spawn_limit_reached")
		spawn_limit_reached.emit()
		return true
	
	# Check max alive
	if is_alive_limit_reached():
		return true
	
	return false
