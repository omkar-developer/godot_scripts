extends RefCounted

class_name FlowFieldManager

var cell_size: int = 32
var grid_width: int = 64
var grid_height: int = 64
var allow_diagonals: bool = true
var diagonal_cost: float = 1.414  # sqrt(2) for accurate pathfinding

signal flow_field_computed(success: bool)

var distances: PackedFloat32Array = []
var flow_vectors: PackedVector2Array = []
var terrain_costs: PackedFloat32Array = []
var _blocked_set: Dictionary = {}

# Threading support
var _thread: Thread = null
var _is_computing: bool = false
var _computation_complete: bool = false
var _mutex: Mutex = Mutex.new()

var occupied: PackedByteArray

# Pre-computed direction arrays
var _cardinal_dirs: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN
]
var _diagonal_dirs: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
]

func _init(_cell_size: int = 32, _grid_width: int = 64, _grid_height: int = 64, _allow_diagonals: bool = true):
	cell_size = _cell_size
	grid_width = _grid_width
	grid_height = _grid_height
	allow_diagonals = _allow_diagonals
	
	var total_cells = grid_height * grid_width
	distances.resize(total_cells)
	flow_vectors.resize(total_cells)
	terrain_costs.resize(total_cells)

	init_occupancy(total_cells)
	
	reset()

func init_occupancy(total_cells: int = grid_width * grid_height):
	occupied.resize(total_cells)
	occupied.fill(0)

func mark_cell(cell: Vector2i, value: bool) -> void:
	if not in_bounds(cell):
		return
	var idx := cell_to_index(cell)
	occupied[idx] = 1 if value else 0

func is_cell_occupied(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return true
	return occupied[cell_to_index(cell)] != 0

func reset():
	distances.fill(INF)
	flow_vectors.fill(Vector2.ZERO)
	terrain_costs.fill(1.0)  # Default cost
	_blocked_set.clear()
	occupied.fill(0)

func index_to_cell(index: int) -> Vector2i:
	return Vector2i(index % grid_width, index / grid_width)

func cell_to_index(cell: Vector2i) -> int:
	return cell.y * grid_width + cell.x

func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / cell_size)), int(floor(pos.y / cell_size)))

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * cell_size + cell_size * 0.5,
		cell.y * cell_size + cell_size * 0.5
	)

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height

func is_blocked(cell: Vector2i) -> bool:
	return _blocked_set.has(cell_to_index(cell))

func set_blocked_cells(blocked: Array[Vector2i]):
	_blocked_set.clear()
	for cell in blocked:
		if in_bounds(cell):
			_blocked_set[cell_to_index(cell)] = true

func add_blocked_cell(cell: Vector2i):
	if in_bounds(cell):
		_blocked_set[cell_to_index(cell)] = true

func remove_blocked_cell(cell: Vector2i):
	if in_bounds(cell):
		_blocked_set.erase(cell_to_index(cell))

func set_terrain_cost(cell: Vector2i, cost: float):
	"""Set movement cost for a cell. 1.0 = normal, higher = slower (sand), lower = faster (road)"""
	if in_bounds(cell):
		_mutex.lock()
		terrain_costs[cell_to_index(cell)] = max(0.1, cost)
		_mutex.unlock()

func set_terrain_cost_area(cells: Array[Vector2i], cost: float):
	"""Set terrain cost for multiple cells at once"""
	cost = max(0.1, cost)
	_mutex.lock()
	for cell in cells:
		if in_bounds(cell):
			terrain_costs[cell_to_index(cell)] = cost
	_mutex.unlock()

func get_terrain_cost(cell: Vector2i) -> float:
	if in_bounds(cell):
		_mutex.lock()
		var cost = terrain_costs[cell_to_index(cell)]
		_mutex.unlock()
		return cost
	return 1.0

func compute_flow_field(goal_cell: Vector2i, blocked: Array[Vector2i] = []):
	"""Compute flow field synchronously (blocks until complete)"""
	reset()
	
	if blocked.size() > 0:
		set_blocked_cells(blocked)
	
	if not in_bounds(goal_cell) or is_blocked(goal_cell):
		push_warning("FlowField: Invalid or blocked goal cell")
		return
	
	_compute_bfs(goal_cell)
	_compute_flow_vectors()

func _on_thread_finished(success: bool = false):
	_is_computing = false
	_computation_complete = false
	flow_field_computed.emit(success)

func compute_flow_field_async(goal_cell: Vector2i, blocked: Array[Vector2i] = []) -> bool:
	"""
	Compute flow field asynchronously in a thread.
	Returns false if already computing, true if started.
	Use is_computing() to check status and poll_completion() to finalize.
	"""
	if _is_computing:
		call_deferred("_on_thread_finished", false)
		return false
	
	if _thread != null and _thread.is_alive():
		call_deferred("_on_thread_finished", false)
		return false
	
	reset()
	
	if blocked.size() > 0:
		set_blocked_cells(blocked)
	
	if not in_bounds(goal_cell) or is_blocked(goal_cell):
		push_warning("FlowField: Invalid or blocked goal cell")
		call_deferred("_on_thread_finished", false)
		return false
	
	_is_computing = true
	_computation_complete = false
	
	# Start thread
	_thread = Thread.new()
	_thread.start(_thread_compute.bind(goal_cell))
	
	call_deferred("_on_thread_finished", true)
	return true

func is_computing() -> bool:
	"""Check if flow field computation is in progress"""
	return _is_computing

func poll_completion() -> bool:
	"""
	Check if async computation is complete and finalize if ready.
	Returns true if computation finished this frame, false otherwise.
	Call this every frame after compute_flow_field_async().
	"""
	if not _is_computing:
		return false
	
	_mutex.lock()
	var complete = _computation_complete
	_mutex.unlock()
	
	if complete:
		if _thread != null and _thread.is_alive():
			_thread.wait_to_finish()
		_is_computing = false
		_computation_complete = false
		return true
	
	return false

func _thread_compute(goal_cell: Vector2i):
	"""Thread worker function"""
	_compute_bfs(goal_cell)
	_compute_flow_vectors()
	
	_mutex.lock()
	_computation_complete = true
	_mutex.unlock()

func _compute_bfs(goal_cell: Vector2i):
	"""Fast BFS algorithm - recommended for real-time updates"""
	var goal_index = cell_to_index(goal_cell)
	distances[goal_index] = 0.0
	
	var queue: Array[Vector2i] = [goal_cell]
	var head = 0
	
	while head < queue.size():
		var current = queue[head]
		head += 1
		
		var current_index = cell_to_index(current)
		var current_dist = distances[current_index]
		
		# Process cardinal directions
		for dir in _cardinal_dirs:
			var neighbor = current + dir
			if not in_bounds(neighbor) or is_blocked(neighbor):
				continue
			
			var n_index = cell_to_index(neighbor)
			if distances[n_index] != INF:
				continue  # Already visited
			
			var terrain_cost = terrain_costs[n_index]
			distances[n_index] = current_dist + terrain_cost
			queue.append(neighbor)
		
		# Process diagonal directions with corner checking
		if allow_diagonals:
			for dir in _diagonal_dirs:
				var neighbor = current + dir
				if not in_bounds(neighbor) or is_blocked(neighbor):
					continue
				
				# MUST check both adjacent cells are passable
				if not _can_move_diagonal(current, dir):
					continue
				
				var n_index = cell_to_index(neighbor)
				if distances[n_index] != INF:
					continue  # Already visited
				
				var terrain_cost = terrain_costs[n_index]
				distances[n_index] = current_dist + (diagonal_cost * terrain_cost)
				queue.append(neighbor)

func _can_move_diagonal(cell: Vector2i, dir: Vector2i) -> bool:
	"""Check if diagonal movement is allowed (no corner cutting through walls)"""
	var horizontal = cell + Vector2i(dir.x, 0)
	var vertical = cell + Vector2i(0, dir.y)
	return not is_blocked(horizontal) and not is_blocked(vertical)

func _compute_flow_vectors():
	for index in range(distances.size()):
		if distances[index] == INF:
			continue
		
		var cell = index_to_cell(index)
		var best_dist = distances[index]
		var best_neighbor = cell
		
		# Check cardinal directions
		for dir in _cardinal_dirs:
			var neighbor = cell + dir
			if not in_bounds(neighbor):
				continue
			
			var n_index = cell_to_index(neighbor)
			var n_dist = distances[n_index]
			
			if n_dist < best_dist:
				best_dist = n_dist
				best_neighbor = neighbor
		
		# Check diagonal directions with corner checking
		if allow_diagonals:
			for dir in _diagonal_dirs:
				var neighbor = cell + dir
				if not in_bounds(neighbor):
					continue
				
				# MUST check both adjacent cells are passable
				if not _can_move_diagonal(cell, dir):
					continue
				
				var n_index = cell_to_index(neighbor)
				var n_dist = distances[n_index]
				
				if n_dist < best_dist:
					best_dist = n_dist
					best_neighbor = neighbor
		
		if best_neighbor != cell:
			flow_vectors[index] = Vector2(best_neighbor - cell).normalized()

func get_flow_at_cell(cell: Vector2i) -> Vector2:
	return get_flow_at_position(cell_to_world(cell))

func get_flow_at_position(world_pos: Vector2) -> Vector2:
	var cell = world_to_cell(world_pos)
	if not in_bounds(cell):
		return Vector2.ZERO
	return flow_vectors[cell_to_index(cell)]

func get_distance_at_position(world_pos: Vector2) -> float:
	var cell = world_to_cell(world_pos)
	if not in_bounds(cell):
		return INF
	return distances[cell_to_index(cell)]

func get_path_to_goal(start_pos: Vector2, max_steps: int = 1000) -> PackedVector2Array:
	var path: PackedVector2Array = []
	var current_pos = start_pos
	var steps = 0
	
	while steps < max_steps:
		var cell = world_to_cell(current_pos)
		if not in_bounds(cell):
			break
		
		var index = cell_to_index(cell)
		var dist = distances[index]
		
		if dist == 0.0 or dist == INF:
			path.append(current_pos)
			break
		
		var flow = flow_vectors[index]
		if flow.length_squared() < 0.01:
			break
		
		current_pos += flow * cell_size * 0.5
		path.append(current_pos)
		steps += 1
	
	return path
