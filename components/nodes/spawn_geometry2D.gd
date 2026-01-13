@tool
class_name SpawnGeometry2D
extends Node2D

## Handles spawn area geometry, position calculation, and visualization for 2D spawning.

## Spawn area shape types
enum AreaShape {
	CIRCLE,      ## Circular spawn area
	RECTANGLE,   ## Rectangular spawn area
	LINE,        ## Linear spawn area (line segment)
	POINT        ## Single point (no randomization)
}

## Spawn location modes
enum SpawnLocation {
	VOLUME,      ## Spawn anywhere inside area
	EDGE,        ## Spawn on edge/perimeter only
	CORNERS      ## Spawn at corners only (rectangle only)
}

## Line spawn distribution modes
enum LineDistribution {
	RANDOM,      ## Random points along line
	EVEN,        ## Evenly spaced points
	SEQUENTIAL   ## Sequential points (use with spawn count/index)
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

## Line: end point of line (start is spawn_center)
@export var line_end: Vector2 = Vector2(100.0, 0.0):
	set(value):
		line_end = value
		queue_redraw()

@export_subgroup("Line Distribution")
## How to distribute spawn points along line
@export var line_distribution: LineDistribution = LineDistribution.RANDOM

## Number of evenly spaced points (EVEN mode) or total points (SEQUENTIAL mode)
@export var line_point_count: int = 5:
	set(value):
		line_point_count = max(1, value)
		queue_redraw()

## Include line endpoints in even/sequential distribution
@export var line_include_endpoints: bool = true

## Current sequential index (for SEQUENTIAL mode, managed externally)
var line_current_index: int = 0

@export_subgroup("Spawn Direction")
## Auto-set spawned entity direction based on spawn area
@export var apply_spawn_direction: bool = false

## Direction mode for different shapes
@export_enum("Outward from center", "Along line direction", "Random", "Fixed angle") var direction_mode: int = 0

## Fixed angle for direction (degrees, used when direction_mode = Fixed angle)
@export var fixed_direction_angle: float = 0.0

## Last spawn position (for direction calculation)
var _last_spawn_position: Vector2 = Vector2.ZERO

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


## Get a random spawn position based on current geometry settings.[br]
## Returns both position and optional direction angle.[br]
## [return]: Local position Vector2 (relative to this node).
func get_spawn_position() -> Vector2:
	var pos: Vector2
	
	match area_shape:
		AreaShape.POINT:
			pos = spawn_center
		AreaShape.CIRCLE:
			pos = _get_circle_spawn_position()
		AreaShape.RECTANGLE:
			pos = _get_rectangle_spawn_position()
		AreaShape.LINE:
			pos = _get_line_spawn_position()
		_:
			pos = spawn_center
	
	_last_spawn_position = pos
	return pos


## Get the direction angle (in radians) for the last spawned position.[br]
## Call this after get_spawn_position() to get corresponding direction.[br]
## [return]: Direction angle in radians.
func get_spawn_direction() -> float:
	if not apply_spawn_direction:
		return 0.0
	
	match direction_mode:
		0: # Outward from center
			return (_last_spawn_position - spawn_center).angle()
		1: # Along line direction (for LINE shape)
			if area_shape == AreaShape.LINE:
				return (line_end - spawn_center).angle()
			return 0.0
		2: # Random
			return randf() * TAU
		3: # Fixed angle
			return deg_to_rad(fixed_direction_angle)
		_:
			return 0.0


## Reset sequential line index (for SEQUENTIAL line distribution)
func reset_line_index() -> void:
	line_current_index = 0


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
		AreaShape.LINE:
			_draw_line_area()
	
	# Draw spawn preview points
	if show_spawn_preview:
		_draw_spawn_preview()


## --- POSITION CALCULATION ---

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


## Get spawn position on line.
func _get_line_spawn_position() -> Vector2:
	match line_distribution:
		LineDistribution.RANDOM:
			# Original random behavior
			match spawn_location:
				SpawnLocation.VOLUME:
					var t := randf()
					return spawn_center.lerp(line_end, t)
				SpawnLocation.EDGE:
					if randf() < 0.5:
						return spawn_center
					else:
						return line_end
				_:
					return spawn_center
		
		LineDistribution.EVEN:
			# Evenly spaced points
			if line_point_count <= 1:
				return spawn_center.lerp(line_end, 0.5)
			
			# Calculate spacing
			var actual_count = line_point_count
			if line_include_endpoints:
				# Points include both ends
				var _t = randf()  # Still random which point to pick
				var index = randi() % actual_count
				var step := 1.0 / float(actual_count - 1) if actual_count > 1 else 0.0
				return spawn_center.lerp(line_end, index * step)
			else:
				# Points between ends
				var index = randi() % actual_count
				var step := 1.0 / float(actual_count + 1)
				return spawn_center.lerp(line_end, (index + 1) * step)
		
		LineDistribution.SEQUENTIAL:
			# Sequential points (for bullet walls)
			if line_point_count <= 1:
				return spawn_center.lerp(line_end, 0.5)
			
			var actual_count = line_point_count
			var index = line_current_index % actual_count
			
			if line_include_endpoints:
				var step := 1.0 / float(actual_count - 1) if actual_count > 1 else 0.0
				return spawn_center.lerp(line_end, index * step)
			else:
				var step := 1.0 / float(actual_count + 1)
				return spawn_center.lerp(line_end, (index + 1) * step)
	
	return spawn_center


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
			var tr_ := rect.position + Vector2(rect.size.x, 0)
			var br := rect.position + rect.size
			var bl := rect.position + Vector2(0, rect.size.y)
			draw_line(tl, tr_, spawn_area_color, 4.0)
			draw_line(tr_, br, spawn_area_color, 4.0)
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


func _draw_line_area() -> void:
	match spawn_location:
		SpawnLocation.VOLUME:
			# Draw line with lighter overlay
			draw_line(spawn_center, line_end, spawn_area_color, 6.0)
			# Draw endpoints
			draw_circle(spawn_center, 4.0, spawn_area_color)
			draw_circle(line_end, 4.0, spawn_area_color)
		
		SpawnLocation.EDGE:
			# Draw line lighter
			draw_line(spawn_center, line_end, Color(spawn_area_color, spawn_area_color.a * 0.3), 3.0)
			# Draw endpoints highlighted
			draw_circle(spawn_center, 6.0, spawn_area_color)
			draw_circle(line_end, 6.0, spawn_area_color)
		
		_:
			draw_line(spawn_center, line_end, spawn_area_color, 4.0)


func _draw_spawn_preview() -> void:
	var point_color := Color(spawn_area_color.r, spawn_area_color.g, spawn_area_color.b, 0.8)
	var point_size := 4.0
	
	for i in range(preview_count):
		var pos := get_spawn_position()
		draw_circle(pos, point_size, point_color)
