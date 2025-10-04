extends Node
class_name FlowFieldObstacleDetector

## Automatically detects obstacles from collision shapes and updates FlowField
## Add this as a child of your main scene and assign the flow_field reference

var flow_field: FlowFieldManager
@export var scan_parent: Node2D  # Parent node containing obstacles (e.g., YSort, TileMap parent)
@export var auto_scan_on_ready: bool = true
@export var collision_mask: int = 1  # Which physics layers to detect

# Optional: Specify groups to scan
@export var obstacle_groups: Array[String] = ["obstacles"]  # Only scan nodes in these groups (empty = scan all)

# Performance settings
@export var use_shape_cast: bool = true  # Use ShapeCast2D for detection (more accurate)
@export var grid_scan_only: bool = false  # Only check grid cells, don't trace shapes

var _detected_obstacles: Array[Vector2i] = []

func _ready():
	if auto_scan_on_ready:
		scan_obstacles()

func scan_obstacles() -> Array[Vector2i]:
	"""
	Scan for obstacles and return blocked cells.
	Automatically updates the flow_field if assigned.
	"""
	if flow_field == null:
		push_warning("FlowFieldObstacleDetector: No flow_field assigned!")
		return []
	
	_detected_obstacles.clear()
	
	if scan_parent == null:
		push_warning("FlowFieldObstacleDetector: No scan_parent assigned!")
		return []
	
	if grid_scan_only:
		_scan_grid_cells()
	else:
		_scan_collision_shapes()
	
	# Update flow field with detected obstacles
	if flow_field != null:
		flow_field.set_blocked_cells(_detected_obstacles)
	
	print("FlowFieldObstacleDetector: Found %d blocked cells" % _detected_obstacles.size())
	return _detected_obstacles

func _scan_grid_cells():
	"""Scan each grid cell using physics queries"""
	var space_state = get_tree().get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.collision_mask = collision_mask
	
	for y in range(flow_field.grid_height):
		for x in range(flow_field.grid_width):
			var cell = Vector2i(x, y)
			var world_pos = flow_field.cell_to_world(cell)
			
			query.position = world_pos
			var result = space_state.intersect_point(query, 1)
			
			if result.size() > 0:
				if _should_include_collider(result[0].collider):
					_detected_obstacles.append(cell)

func _scan_collision_shapes():
	"""Scan all CollisionShape2D/CollisionPolygon2D nodes and convert to grid cells"""
	var nodes_to_scan = []
	
	if obstacle_groups.size() > 0:
		# Scan specific groups
		for group in obstacle_groups:
			nodes_to_scan.append_array(get_tree().get_nodes_in_group(group))
	else:
		# Scan all children
		nodes_to_scan = _get_all_children(scan_parent)
	
	for node in nodes_to_scan:
		if node is StaticBody2D or node is CharacterBody2D or node is RigidBody2D or node is Area2D:
			_process_physics_body(node)
		elif node is TileMap:
			_process_tilemap(node)

func _process_physics_body(body: Node2D):
	"""Extract blocked cells from a physics body's collision shapes"""
	for child in body.get_children():
		if child is CollisionShape2D:
			_process_collision_shape(child)
		elif child is CollisionPolygon2D:
			_process_collision_polygon(child)

func _process_collision_shape(shape_node: CollisionShape2D):
	"""Convert a CollisionShape2D to grid cells"""
	if shape_node.shape == null or shape_node.disabled:
		return
	
	var shape = shape_node.shape
	var global_transform = shape_node.global_transform
	
	# Get approximate bounds
	var rect = _get_shape_rect(shape, global_transform)
	
	# Convert bounds to grid cells
	var min_cell = flow_field.world_to_cell(rect.position)
	var max_cell = flow_field.world_to_cell(rect.end)
	
	# Add all cells in the bounding box
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell = Vector2i(x, y)
			if flow_field.in_bounds(cell) and not _detected_obstacles.has(cell):
				# Optional: Do more precise check for complex shapes
				var cell_world = flow_field.cell_to_world(cell)
				if _point_in_shape(cell_world, shape, global_transform):
					_detected_obstacles.append(cell)

func _process_collision_polygon(poly_node: CollisionPolygon2D):
	"""Convert a CollisionPolygon2D to grid cells"""
	if poly_node.disabled or poly_node.polygon.size() < 3:
		return
	
	var global_transform = poly_node.global_transform
	var transformed_points: PackedVector2Array = []
	
	for point in poly_node.polygon:
		transformed_points.append(global_transform * point)
	
	# Get bounding box
	var min_pos = transformed_points[0]
	var max_pos = transformed_points[0]
	
	for point in transformed_points:
		min_pos.x = min(min_pos.x, point.x)
		min_pos.y = min(min_pos.y, point.y)
		max_pos.x = max(max_pos.x, point.x)
		max_pos.y = max(max_pos.y, point.y)
	
	var min_cell = flow_field.world_to_cell(min_pos)
	var max_cell = flow_field.world_to_cell(max_pos)
	
	# Check each cell in bounding box
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell = Vector2i(x, y)
			if flow_field.in_bounds(cell) and not _detected_obstacles.has(cell):
				var cell_world = flow_field.cell_to_world(cell)
				if _point_in_polygon(cell_world, transformed_points):
					_detected_obstacles.append(cell)

func _process_tilemap(tilemap: TileMap):
	"""Extract blocked cells from a TileMap"""
	# This is a basic implementation - adjust based on your TileMap setup
	for cell in tilemap.get_used_cells(0):  # Layer 0
		var world_pos = tilemap.map_to_local(cell)
		var grid_cell = flow_field.world_to_cell(world_pos)
		
		if flow_field.in_bounds(grid_cell) and not _detected_obstacles.has(grid_cell):
			_detected_obstacles.append(grid_cell)

func _get_shape_rect(shape: Shape2D, transform: Transform2D) -> Rect2:
	"""Get approximate bounding rect for a shape"""
	if shape is RectangleShape2D:
		var size = shape.size
		var pos = transform.origin - size * 0.5
		return Rect2(pos, size)
	elif shape is CircleShape2D:
		var radius = shape.radius
		var pos = transform.origin - Vector2(radius, radius)
		return Rect2(pos, Vector2(radius * 2, radius * 2))
	elif shape is CapsuleShape2D:
		var radius = shape.radius
		var height = shape.height
		var size = Vector2(radius * 2, height)
		var pos = transform.origin - size * 0.5
		return Rect2(pos, size)
	else:
		# Fallback: use a default size
		var size = Vector2(flow_field.cell_size, flow_field.cell_size)
		return Rect2(transform.origin - size * 0.5, size)

func _point_in_shape(point: Vector2, shape: Shape2D, transform: Transform2D) -> bool:
	"""Check if a point is inside a shape (simplified)"""
	var local_point = transform.affine_inverse() * point
	
	if shape is RectangleShape2D:
		var half_size = shape.size * 0.5
		return abs(local_point.x) <= half_size.x and abs(local_point.y) <= half_size.y
	elif shape is CircleShape2D:
		return local_point.length() <= shape.radius
	elif shape is CapsuleShape2D:
		var half_height = shape.height * 0.5 - shape.radius
		if abs(local_point.y) <= half_height:
			return abs(local_point.x) <= shape.radius
		else:
			var circle_center = Vector2(0, sign(local_point.y) * half_height)
			return (local_point - circle_center).length() <= shape.radius
	
	return true  # Conservative: assume point is inside for unknown shapes

func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	"""Check if point is inside polygon using ray casting algorithm"""
	var inside = false
	var j = polygon.size() - 1
	
	for i in range(polygon.size()):
		if ((polygon[i].y > point.y) != (polygon[j].y > point.y)) and \
		   (point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x):
			inside = not inside
		j = i
	
	return inside

func _should_include_collider(collider: Node) -> bool:
	"""Check if a collider should be included based on groups"""
	if obstacle_groups.size() == 0:
		return true
	
	for group in obstacle_groups:
		if collider.is_in_group(group):
			return true
	
	return false

func _get_all_children(node: Node) -> Array:
	"""Recursively get all children of a node"""
	var children = []
	for child in node.get_children():
		children.append(child)
		children.append_array(_get_all_children(child))
	return children

func rescan():
	"""Convenience method to rescan obstacles"""
	scan_obstacles()
