@tool
class_name SpawnerComponent
extends BaseSpawner

## Spatial spawner component with patterns, timers, and visual helpers.[br]
##[br]
## Extends BaseSpawner with spawn area geometry (circle, rectangle, point),[br>
## spawn timing modes (interval, wave, list), and editor visualization.

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

## Spawn timing modes
enum TimingMode {
	INTERVAL,    ## Spawn at regular intervals
	WAVE,        ## Spawn in waves (burst of entities)
	LIST         ## Follow predefined spawn list with delays
}

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
@export var spawn_list: Dictionary[float, Array] = {}

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

## Label spawner for floating text system
var _label_spawner: LabelSpawner = null

## Floating text component for damage numbers
var _floating_text_component: FloatingTextComponent = null

## --- SIGNALS ---

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


func _enter_tree() -> void:
	# Setup floating text system
	_label_spawner = LabelSpawner.new(get_parent(), 20)
	_label_spawner.configure_defaults(16, true, Color.BLACK, 2)
	_floating_text_component = FloatingTextComponent.new(self, get_parent(), _label_spawner)
	_floating_text_component.float_speed = 60.0
	_floating_text_component.duration = 1.2
	
	# Register as injectable services
	register_service("label_spawner", _label_spawner)
	register_service("floating_text_component", _floating_text_component)


func _ready() -> void:
	super._ready()
	
	# Editor mode - only parse properties
	if Engine.is_editor_hint():
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
	# Editor: just redraw if needed
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
	
	if not is_spawning or is_paused:
		return
	
	# Check spawn limits
	if max_spawns >= 0 and total_spawned >= max_spawns:
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
## [param position_override]: Optional position override (null = use spawn area).[br]
## [return]: Spawned entity Node, or null if failed.
func spawn_entity(scene_index: int = -1, position_override: Variant = null) -> Node:
	var pos = position_override if position_override != null else _get_spawn_position()
	return spawn(pos, scene_index)


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


## Reset counters and timers.
func reset() -> void:
	super.reset()
	_spawn_timer = 0.0
	_list_index = 0
	_current_delay = 0.0


## Get spawner statistics.[br]
## [return]: Dictionary with stats.
func get_stats() -> Dictionary:
	var stats = super.get_stats()
	stats.merge({
		"is_spawning": is_spawning,
		"is_paused": is_paused,
		"timing_mode": TimingMode.keys()[timing_mode],
		"area_shape": AreaShape.keys()[area_shape],
		"spawn_location": SpawnLocation.keys()[spawn_location]
	})
	return stats


## --- INTERNAL TIMING MODE UPDATES ---

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
			var wave_num := floori(total_spawned / float(wave_size))
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
			var angle := randf() * TAU
			var radius := sqrt(randf()) * spawn_radius
			return spawn_center + Vector2(cos(angle), sin(angle)) * radius
		SpawnLocation.EDGE:
			var angle := randf() * TAU
			return spawn_center + Vector2(cos(angle), sin(angle)) * spawn_radius
		_:
			return spawn_center


## Get spawn position in rectangle.
func _get_rectangle_spawn_position() -> Vector2:
	var half_size := spawn_size / 2.0
	
	match spawn_location:
		SpawnLocation.VOLUME:
			var offset := Vector2(
				randf_range(-half_size.x, half_size.x),
				randf_range(-half_size.y, half_size.y)
			)
			return spawn_center + offset
		
		SpawnLocation.EDGE:
			var side := randi() % 4
			match side:
				0: return spawn_center + Vector2(randf_range(-half_size.x, half_size.x), -half_size.y)
				1: return spawn_center + Vector2(half_size.x, randf_range(-half_size.y, half_size.y))
				2: return spawn_center + Vector2(randf_range(-half_size.x, half_size.x), half_size.y)
				3: return spawn_center + Vector2(-half_size.x, randf_range(-half_size.y, half_size.y))
		
		SpawnLocation.CORNERS:
			var corner := randi() % 4
			var offset := half_size
			match corner:
				0: offset = Vector2(-half_size.x, -half_size.y)
				1: offset = Vector2(half_size.x, -half_size.y)
				2: offset = half_size
				3: offset = Vector2(-half_size.x, half_size.y)
			return spawn_center + offset
	
	return spawn_center


## Override to add timer and wave context.
func _get_context_value(source: SpawnPropertyValue.ContextSource) -> float:
	match source:
		SpawnPropertyValue.ContextSource.TIME_ELAPSED:
			return _spawn_timer
		SpawnPropertyValue.ContextSource.WAVE_NUMBER:
			if timing_mode == TimingMode.WAVE and wave_size > 0:
				return float(floori(total_spawned / float(wave_size)))
			return 0.0
		_:
			return super._get_context_value(source)


## --- DRAWING METHODS ---

func _draw_point_area() -> void:
	var point_size := 8.0
	draw_circle(spawn_center, point_size, spawn_area_color)


func _draw_circle_area() -> void:
	var points := 64
	var step := TAU / points
	
	match spawn_location:
		SpawnLocation.VOLUME:
			draw_circle(spawn_center, spawn_radius, Color(spawn_area_color, spawn_area_color.a * 0.3))
			for i in range(points):
				var angle1 := i * step
				var angle2 := (i + 1) * step
				var p1 := spawn_center + Vector2(cos(angle1), sin(angle1)) * spawn_radius
				var p2 := spawn_center + Vector2(cos(angle2), sin(angle2)) * spawn_radius
				draw_line(p1, p2, spawn_area_color, 2.0)
		
		SpawnLocation.EDGE:
			for i in range(points):
				var angle1 := i * step
				var angle2 := (i + 1) * step
				var p1 := spawn_center + Vector2(cos(angle1), sin(angle1)) * spawn_radius
				var p2 := spawn_center + Vector2(cos(angle2), sin(angle2)) * spawn_radius
				draw_line(p1, p2, spawn_area_color, 4.0)


func _draw_rectangle_area() -> void:
	var half_size := spawn_size / 2.0
	var rect := Rect2(spawn_center - half_size, spawn_size)
	
	match spawn_location:
		SpawnLocation.VOLUME:
			draw_rect(rect, Color(spawn_area_color, spawn_area_color.a * 0.3))
			draw_rect(rect, spawn_area_color, false, 2.0)
		
		SpawnLocation.EDGE:
			var tl := rect.position
			var tr := rect.position + Vector2(rect.size.x, 0)
			var br := rect.position + rect.size
			var bl := rect.position + Vector2(0, rect.size.y)
			draw_line(tl, tr, spawn_area_color, 4.0)
			draw_line(tr, br, spawn_area_color, 4.0)
			draw_line(br, bl, spawn_area_color, 4.0)
			draw_line(bl, tl, spawn_area_color, 4.0)
		
		SpawnLocation.CORNERS:
			var corner_size := 10.0
			var corners := [
				rect.position,
				rect.position + Vector2(rect.size.x, 0),
				rect.position + rect.size,
				rect.position + Vector2(0, rect.size.y)
			]
			for corner in corners:
				draw_circle(corner, corner_size, spawn_area_color)


func _draw_spawn_preview() -> void:
	var point_color := Color(spawn_area_color.r, spawn_area_color.g, spawn_area_color.b, 0.8)
	var point_size := 4.0
	
	for i in range(preview_count):
		var pos := _get_spawn_position() - global_position
		draw_circle(pos, point_size, point_color)
