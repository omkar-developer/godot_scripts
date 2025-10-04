extends Node2D
class_name FlowFieldDrawer

var flow_field: FlowFieldManager
@export var blocked: Array[Vector2i] = []
@export var goal: Vector2i = Vector2i(-1, -1)

@export var show_grid: bool = true
@export var show_vectors: bool = true
@export var show_distances: bool = false
@export var show_terrain_costs: bool = true
@export var color_vectors_by_direction: bool = true  # Color arrows by direction

@export var grid_color: Color = Color(0.3, 0.3, 0.3, 0.5)
@export var vector_color: Color = Color(0, 1, 0, 0.8)  # Used when not coloring by direction
@export var blocked_color: Color = Color.BLACK
@export var goal_color: Color = Color.RED
@export var unreachable_color: Color = Color(0.2, 0, 0, 0.3)

func _draw():
	if flow_field == null:
		return

	var cell_size = flow_field.cell_size

	# Draw terrain costs (if enabled)
	if show_terrain_costs:
		for y in range(flow_field.grid_height):
			for x in range(flow_field.grid_width):
				var cell = Vector2i(x, y)
				var index = flow_field.cell_to_index(cell)
				var cost = flow_field.terrain_costs[index]
				
				# Only draw if cost is different from default (1.0)
				if abs(cost - 1.0) > 0.01 and not flow_field.is_blocked(cell):
					var rect = Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
					# Red tint for high cost (slow terrain), green for low cost (fast terrain)
					var color: Color
					if cost > 1.0:
						var intensity = min((cost - 1.0) / 2.0, 1.0)  # 1.0 to 3.0 -> 0 to 1
						color = Color(1.0, 0.5 - intensity * 0.5, 0, 0.3)  # Orange to red
					else:
						var intensity = 1.0 - cost  # 0.5 to 1.0 -> 0.5 to 0
						color = Color(0, 1.0, 0, 0.3)  # Green
					draw_rect(rect, color, true)

	# Draw unreachable cells
	if show_distances:
		for y in range(flow_field.grid_height):
			for x in range(flow_field.grid_width):
				var cell = Vector2i(x, y)
				var index = flow_field.cell_to_index(cell)
				if flow_field.distances[index] == INF:
					var rect = Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
					draw_rect(rect, unreachable_color, true)

	# Draw grid
	if show_grid:
		# Optimized: draw horizontal and vertical lines
		for y in range(flow_field.grid_height + 1):
			var y_pos = y * cell_size
			draw_line(Vector2(0, y_pos), Vector2(flow_field.grid_width * cell_size, y_pos), grid_color, 1)
		
		for x in range(flow_field.grid_width + 1):
			var x_pos = x * cell_size
			draw_line(Vector2(x_pos, 0), Vector2(x_pos, flow_field.grid_height * cell_size), grid_color, 1)

	# Draw blocked cells
	for cell in blocked:
		var rect = Rect2(cell.x * cell_size, cell.y * cell_size, cell_size, cell_size)
		draw_rect(rect, blocked_color, true)

	# Draw goal cell
	if goal.x != -1 and goal.y != -1:
		var rect = Rect2(goal.x * cell_size, goal.y * cell_size, cell_size, cell_size)
		draw_rect(rect, goal_color, true)

	# Draw flow vectors
	if show_vectors:
		for index in range(flow_field.distances.size()):
			# Skip if unreachable or blocked
			if flow_field.distances[index] == INF:
				continue
			
			var dir = flow_field.flow_vectors[index]
			if dir.length_squared() < 0.001:  # At goal or no flow
				continue

			var cell = flow_field.index_to_cell(index)
			var world_pos = flow_field.cell_to_world(cell)

			# Choose color based on direction
			var arrow_color: Color
			if color_vectors_by_direction:
				arrow_color = _get_direction_color(dir)
			else:
				arrow_color = vector_color

			var end = world_pos + dir * (cell_size * 0.4)
			draw_line(world_pos, end, arrow_color, 2)

			# Arrow head
			var perp = dir.orthogonal() * (cell_size * 0.1)
			draw_line(end, end - dir * (cell_size * 0.15) + perp, arrow_color, 2)
			draw_line(end, end - dir * (cell_size * 0.15) - perp, arrow_color, 2)
	
	# Draw distance values (optional, for debugging small grids)
	if show_distances and flow_field.grid_width <= 32:
		for y in range(flow_field.grid_height):
			for x in range(flow_field.grid_width):
				var cell = Vector2i(x, y)
				var index = flow_field.cell_to_index(cell)
				var dist = flow_field.distances[index]
				if dist != INF:
					var pos = flow_field.cell_to_world(cell)
					draw_string(ThemeDB.fallback_font, pos - Vector2(8, -4), "%.1f" % dist, 
								HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)

func _get_direction_color(direction: Vector2) -> Color:
	"""Convert direction vector to a color based on angle"""
	var angle = direction.angle()  # Returns angle in radians (-PI to PI)
	var hue = (angle + PI) / (2 * PI)  # Normalize to 0-1
	return Color.from_hsv(hue, 0.8, 1.0, 0.9)  # Vibrant colors based on direction
